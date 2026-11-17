# Fluxo PB: atlas, máscara e material de inspeção

Scripts para Blender 5.2+; testados no Blender 5.2.2. O atlas do exemplo é uma cópia independente em `assets/estilo_pb/radio_atlas_demo_input.png`. A arte original em `assets/environment/casa/` e os modelos do jogo ficam intactos.

## Extrair tons de cinza e linhas

No PowerShell, a partir da raiz `DelusioGame/Delusio`:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' -b --factory-startup --disable-autoexec --python-exit-code 1 --python tools/blender/estilo_pb/extract_mask.py -- `
  --source assets/estilo_pb/radio_atlas_demo_input.png `
  --gray-output assets/estilo_pb/meu_atlas_cinza.png `
  --output assets/estilo_pb/minha_mascara.png `
  --threshold 0.18 --width 1
```

Use nomes inéditos para os caminhos de saída. O CLI recusa sobrescrever arquivos existentes.

O CLI trata as amostras RGB da fonte como sRGB, converte para luminância linear antes de medir diferenças, e grava o mapa grayscale em tons sRGB com alpha copiado. A máscara mantém RGB preto fora das bordas e RGB branco nas bordas; o alpha da fonte é copiado. Em texels com alpha zero, RGB da máscara é forçado a preto inclusive após dilatação, evitando bordas em áreas totalmente transparentes. Em texels com alpha parcial, a borda permanece branca e o alpha original parcial é preservado; como Godot lê a máscara por luminância RGB, a opacidade parcial continua vindo da textura base/material. O algoritmo marca diferenças horizontais/verticais de luminância linear maiores que o limiar normalizado de 0–1 e alarga o traço por dilatação quadrada. Threshold zero numa imagem uniforme produz máscara vazia. Threshold e largura são ajustáveis: limiar menor identifica diferenças mais sutis e pode incluir mais textura/ruído; largura maior engrossa as linhas em pixels. O exemplo deste atlas usa threshold `0.18` e width `1`, que preservam mais detalhes reconhecíveis. `--width 1` mantém a espessura detectada; valores maiores engrossam em pixels. O arquivo fonte nunca é gravado. O CLI reporta caminhos, dimensões, limiar, espessura e quantidade de bordas detectadas em `@@JSON@@`. Recusa saídas já existentes, inclusive links pendentes. `--python-exit-code 1` faz o Blender propagar falhas do script para o status do processo.

## Exemplo de `.blend` e preview

Depois de extrair a máscara:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' -b --factory-startup --disable-autoexec --python-exit-code 1 --python tools/blender/estilo_pb/build_preview.py -- `
  --source assets/estilo_pb/radio_atlas_demo_input.png `
  --mask assets/estilo_pb/minha_mascara.png `
  --blend assets/estilo_pb/meu_preview.blend `
  --preview assets/estilo_pb/meu_preview.png
```

Use nomes inéditos para o `.blend` e o preview PNG também; o gerador recusa saídas existentes. Ele só roda em processo headless novo, inicializado com `-b --factory-startup --disable-autoexec`. Se houver um `.blend` aberto ou a interface estiver em uso, ele interrompe antes de alterar a cena.

O `.blend` inclui as imagens empacotadas e uma cena ilustrativa que compara atlas original, máscara, grayscale e esfera UV com o material PB para avaliar os nós e o rim. A pasta do projeto contém o atlas e um GLB da casa, mas não um modelo de rádio isolado para esta ferramenta; portanto, o preview não representa o rádio final no jogo. No material `PB | Black + painted white details + rim`, pixels pretos da máscara deixam a base preta e pixels brancos revelam os detalhes brancos. O node Fresnel aproxima um rim dependente do ângulo de visão para visualização; o atlas original está guardado como referência no editor de nós. O nó Image Texture da máscara fica selecionado/ativo no `.blend` para facilitar Texture Paint.

### Reutilizar o material em outro modelo

1. No arquivo do seu modelo, use **File > Append**, abra `assets/estilo_pb/radio_atlas_demo.blend`, entre em `Material` e selecione `PB | Black + painted white details + rim`.
2. Atribua o material ao objeto ou a uma cópia do objeto. Para preservar o original, duplique o objeto antes de atribuir/editar.
3. Abra o Shader Editor do material. No nó de imagem de máscara (rotulado `White pixels = hand-painted / extracted details`), escolha a máscara PNG correspondente ao seu modelo. No nó de referência `Original texture — source/reference; not modified`, troque a imagem pela textura original que deseja documentar. Esse nó de origem é apenas uma referência; o material mostra o preto e os detalhes a partir da máscara conectada.
4. Confira o UV Map do objeto. A textura original e a máscara precisam compartilhar o mesmo layout UV. Se o modelo usa outra textura/atlas, gere ou pinte a máscara nesse espaço UV e confirme que o objeto tem UVs válidos; malhas sem UVs ou com ilhas diferentes precisam de UVs preparados para esse atlas.
5. Salve as imagens editadas como novos PNGs e empacote ou salve o `.blend` em uma pasta que mantenha esses recursos acessíveis. O Append copia os dados do material para o arquivo atual; trocar a imagem nos nós faz o material apontar para a imagem selecionada.

O material não analisa a textura de origem nem extrai linhas automaticamente: ele apenas exibe a imagem ligada ao nó de máscara. Gere a máscara antes com `extract_mask.py` ou pinte-a à mão. O rim Fresnel é uma aproximação de visualização em Blender e depende da geometria/normais e do ângulo da câmera.

### Pintar detalhes à mão

1. Abra `radio_atlas_demo.blend` e selecione a imagem `radio_atlas_demo_mask.png` no Editor de Imagens.
2. Para manter a extração automática reproduzível, duplique a máscara antes de editar (`Image > Save As...`) e reabra a cópia; use essa cópia como imagem do nó de máscara.
3. No Texture Paint, escolha branco puro para acrescentar linhas/detalhes e preto para apagá-los. Mantenha RGB preto visível no fundo e RGB branco nos detalhes. Como Godot lê a máscara por luminância (RGB), deixe alpha em 1 (opaco) na máscara pintada, a menos que o shader passe a usar alpha explicitamente. Use modo de mesclagem Replace e salve a imagem (`Image > Save`). O branco é a cor que o material exibe.
4. A máscara está no espaço UV do atlas. Pinte apenas dentro das ilhas UV correspondentes ao objeto e deixe margem suficiente para mipmaps/filtragem.

O `.blend` serve para autoria e inspeção; nenhuma árvore procedural do Blender é necessária no jogo. Exporte o atlas base e a máscara como PNG separados. A máscara deve ser uma textura linear/data (sem correção de cor sRGB para os valores), com preto no fundo e branco nos detalhes.

## Godot

Importe `radio_atlas_demo_mask.png` no projeto e ligue a textura ao uniforme `mascara_detalhes` do shader do objeto. Mantenha o UV do material alinhado ao mesmo atlas. Se usar esta máscara já extraída, desligue `usar_extracao_automatica`; se deixar a extração ativa, as linhas podem ser detectadas e desenhadas uma segunda vez. O efeito animado de contorno/rim deve ser feito pelo shader Godot em tempo real: o rim Fresnel do Blender é apenas aproximação estática para inspeção e não é exportado. A máscara exportada é um mapa PNG simples e compatível com o shader.

## Validação

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' -b --factory-startup --disable-autoexec --python-exit-code 1 --python tools/blender/estilo_pb/test_extract_mask.py
```

O teste cria uma imagem sintética de borda vertical conhecida e verifica contagem de pixels, alpha, hash da fonte e proteção de saída existente. Também confira se os PNGs e o `.blend` foram criados e se o preview mostra as quatro amostras.

O teste de segurança verifica colisões entre origem, máscara, `.blend` e preview; para confirmar que um arquivo carregado é recusado antes de apagar objetos, execute:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' -b --factory-startup --disable-autoexec --python-exit-code 1 assets/estilo_pb/radio_atlas_demo.blend --python tools/blender/estilo_pb/test_preview_safety.py
```

Reabertura e checagem dos recursos empacotados:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' -b --factory-startup --disable-autoexec --python-exit-code 1 assets/estilo_pb/radio_atlas_demo.blend --python tools/blender/estilo_pb/verify_blend.py
```

Limitações: detecção é baseada em contraste da textura e não sabe quais linhas são semânticas; ruído, textura impressa e juntas de cor também viram arestas. Dilatação é quadrada e não faz antialias. A extração é por pixel do atlas inteiro, não por objeto/ilha UV. Para controlar detalhes com precisão, pinte uma cópia da máscara ou limpe falsos positivos no editor de imagem.
