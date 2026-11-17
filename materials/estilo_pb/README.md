# Estilo PB por item

Este pacote aplica uma aparência preta com linhas brancas extraídas da textura, rim light branco e casco de contorno branco com faixa animada. A extração automática é feita no shader a partir da textura da superfície, por isso o mesmo aplicador pode ser usado em malhas diferentes desde que tenham UV1 e uma textura com detalhes legíveis. O helper cria materiais locais por superfície; ele não modifica materiais compartilhados nem exige alterações ao projeto ou ao ambiente global.

## Aplicação e restauração

```gdscript
const AplicadorEstiloPB = preload("res://scripts/visual/estilo_pb/aplicador_estilo_pb.gd")
var estilo := AplicadorEstiloPB.new()

func _ready() -> void:
	var mascara: Texture2D = load("res://caminho/minha_mascara.png")
	estilo.aplicar($MeuMeshInstance, {
		"mascara_detalhes": mascara,
		"usar_extracao_automatica": true,
		"limiar_luminancia": 0.25,
		"forca_linhas": 1.0,
		"limiar_borda": 0.5,
		"intensidade_rim": 1.0,
		"largura_rim": 0.12,
		"espessura_contorno": 0.04,
		"velocidade_faixa": 0.45,
		"intensidade_faixa": 2.5,
	})

func _exit_tree() -> void:
	estilo.restaurar($MeuMeshInstance)
```

Para um nó importado com subárvore de objetos (por exemplo, uma casa ou rádio do GLB), use `estilo.aplicar_arvore($Radio, parametros)` e, ao sair, `estilo.restaurar_arvore($Radio)`. O helper percorre o nó e seus descendentes e aplica uma instância independente a cada `MeshInstance3D` encontrado.

O helper é uma instância `RefCounted` e mantém estado apenas para os itens passados a ela. Chamadas repetidas em um mesmo item são idempotentes e mantêm os parâmetros da primeira aplicação; para mudar parâmetros, chame `restaurar(item)` e depois `aplicar(item, parametros_atualizados)`. `restaurar(item)` repõe os overrides originais somente quando ainda encontra o material que o helper instalou, preservando alterações feitas por outros sistemas enquanto o efeito estava ativo. Use a mesma instância do helper para restaurar. Itens liberados sem restauração são removidos do estado fraco na próxima chamada do helper.

Cada `MeshInstance3D` e superfície recebe seu próprio `ShaderMaterial`. O material ativo antes da aplicação é consultado nesta ordem: override global do item, override da superfície e material da malha, seguindo a precedência visual do Godot. Textura, cor, escala e offset UV1 são copiados de materiais `BaseMaterial3D`. O preset inspecionável está em `materials/estilo_pb/preset_estilo_pb.tres`.

## Aplicação pelo Inspector, sem código

1. Adicione ou selecione o `MeshInstance3D` na cena e confirme que a malha tem UV1.
2. Abra `materials/estilo_pb/preset_estilo_pb.tres` e duplique o recurso uma vez para cada textura/superfície que receberá o efeito. Dê nomes distintos às cópias para não editar acidentalmente um recurso compartilhado.
3. No ShaderMaterial duplicado, abra **Shader Parameters** e informe `textura_original` com a textura daquela superfície, `tem_textura = true` e `tamanho_textura` com a largura e altura da imagem em pixels. Para uma superfície sem textura, deixe `tem_textura = false`.
4. A extração automática já vem ligada. Para adicionar ou corrigir linhas à mão, informe `mascara_detalhes` e marque `tem_mascara_detalhes = true`. Deixe `usar_extracao_automatica = true` para combinar as linhas detectadas com as pintadas; desligue para mostrar somente a máscara. Pinte os detalhes brancos sobre fundo preto e salve em PNG; a máscara é lida como dado linear.
5. Em **Geometry > Surface Material Override**, atribua a cópia correspondente a cada índice de superfície. Cada textura distinta exige sua própria cópia com `textura_original`, `tamanho_textura` e máscara correspondentes. O `next_pass` de contorno branco animado já está configurado no preset.
6. Se a textura usa alpha, ative `usar_alpha` no passe principal e, no recurso `next_pass`, defina `textura_alpha`, `tem_textura_alpha`, `usar_alpha`, `alpha_cor_base` e `alpha_cutout_threshold` com os mesmos valores da superfície. O helper por script copia esses valores automaticamente.
7. Para ver o halo, habilite **Glow** no `WorldEnvironment` ativo da própria cena. A demo traz uma configuração isolada para copiar; não é preciso alterar o ambiente global do jogo.

## Parâmetros

- `usar_extracao_automatica`: detecta contrastes locais da textura original e os desenha em branco sobre a superfície preta. A extração é calculada separadamente para cada material/superfície; desligue para usar somente a máscara manual e o rim light.
- `realcar_areas_claras`: opcional, desligado por padrão; quando ligado, também ilumina áreas acima do limiar de luminância. Por padrão, as partes claras da textura continuam pretas e somente Sobel, máscara manual e rim light ficam brancos.
- `mascara_detalhes`: PNG independente de fundo preto e linhas brancas, aplicado como padrão a todas as superfícies. Use `mascaras_por_superficie: {0: mascara_a, 1: mascara_b}` para atlas separados por índice (chaves string, como `"0"`, também são aceitas). A máscara é combinada com a extração automática pelo maior valor.
- `escala_automatica`: ligada por padrão, ajusta o raio de leitura ao tamanho da textura, entre 1 e 6 pixels. Desligue para usar raio fixo de 1 pixel. Isso ajuda a comparar texturas pequenas e grandes com uma escala inicial adequada.
- `limiar_luminancia`, `limiar_borda`, `forca_linhas` e `escala_amostragem`: ajustam os detalhes que a extração automática detecta. Reduza `limiar_borda` para revelar contrastes mais sutis; aumente-o para remover linhas fracas ou ruído. `escala_amostragem` multiplica o raio escolhido: valores maiores podem revelar detalhes maiores ou de baixo contraste, enquanto valores menores favorecem traços finos. A métrica de gradiente em RGB perceptual tem escala diferente da versão antiga em luminância; comece perto do limiar padrão de `0.5` e ajuste com a malha visível. Atlas com tamanhos, contraste e estilo artístico diferentes podem precisar de valores distintos.
- `intensidade_rim` e `largura_rim`: força e largura do efeito Fresnel.
- `espessura_contorno`: expansão do casco invertido. `velocidade_faixa`, `largura_faixa`, `escala_faixa` e `intensidade_faixa` configuram a faixa que percorre o eixo Y local. `intensidade_glow` aumenta o brilho HDR da faixa no casco.
- `alpha_cutout_threshold`: limiar de recorte para texturas e materiais com alpha.

O shader calcula gradientes em RGB perceptual, comparando a cor de amostras vizinhas em vez de depender apenas da luminância; assim pode revelar detalhes escuros e transições de cor com luminância parecida. O rádio da demonstração usa uma máscara PNG de linhas preparada previamente, então seu resultado não representa sozinho a extração automática. A cama usa seu próprio atlas e a extração automática; por isso a aparência pode diferir mesmo com o mesmo material. Para manter o traço desejado em objetos diferentes, use a extração automática como base e acrescente uma máscara manual por objeto/superfície quando precisar preservar linhas específicas. Máscaras são imagens pretas com linhas brancas e podem ser pintadas no Blender usando o mesmo UV da textura.

O halo precisa de glow/bloom na cena. A faixa aumenta o brilho HDR do `ALBEDO` do casco para funcionar também no passe `unshaded`; o glow do ambiente cria o halo. A cena isolada `scenes/demos/estilo_pb/demo_estilo_pb.tscn` configura `WorldEnvironment` com glow para pré-visualização. O ambiente de jogo não é alterado.

## Limitações

Materiais transparentes em blend são aproximados como alpha cutout. A ordem de desenho e o blending de objetos transparentes não são preservados. Materiais opacos ignoram alpha da textura, como o material original; materiais com alpha aplicam ao casco a mesma amostra UV1, alpha da cor base e limiar de recorte da superfície. O shader principal renderiza os dois lados para preservar materiais double-sided, com custo de desenhar faces traseiras. A extração automática faz várias leituras da textura por fragmento; o custo cresce com a quantidade de superfícies e pixels cobertos e pode ser maior que o de uma máscara PNG já preparada. Uma textura uniforme não contém contrastes dos quais o detector possa criar linhas; nesse caso, pinte uma máscara manual. Contrastes muito pequenos podem desaparecer e granulação ou padrões miúdos podem virar ruído branco; ajuste a sensibilidade e a escala de amostragem, ou use máscara para controlar o desenho. Materiais `ShaderMaterial` de origem não são interpretados; o helper emite aviso e usa branco como base. Superfícies sem UV1 emitem aviso; a aplicação continua, mas textura e máscara não serão amostradas corretamente. O casco usa normais existentes e pode apresentar espessura variável em normais duras, além de artefatos em malhas abertas ou muito finas. Samplers usam repetição e filtro nearest; modos próprios do material como Repeat Disabled ou Mirrored não são copiados.

## Demonstração e validação

Abra `scenes/demos/estilo_pb/demo_estilo_pb.tscn` para ver a malha `Cube_017` do GLB da casa, cuja textura usa o atlas de rádio, com a máscara `assets/estilo_pb/radio_atlas_demo_mask.png`. Se o GLB ou imagem não estiver disponível, a demo usa caixa e textura de madeira local. Como o PNG de máscara do exemplo já contém linhas extraídas, a demo desliga `usar_extracao_automatica` por padrão; ative a propriedade exportada no inspetor para comparar a extração automática. O contorno animado e glow aparecem com o `WorldEnvironment` local da demo. Os testes sem dependências externas ficam em `scripts/tests/visual/estilo_pb/teste_aplicador_estilo_pb.gd` e podem ser executados assim:

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://scripts/tests/visual/estilo_pb/teste_aplicador_estilo_pb.gd
```

O teste temporal precisa de um renderer gráfico real e não deve ser executado com `--headless`:

```powershell
Godot_v4.7.2-stable_win64_console.exe --path . --script res://scripts/tests/visual/estilo_pb/teste_animacao_estilo_pb.gd
```

Ele captura dois frames separados por 730 ms, chama `RenderingServer.force_draw()` e verifica que a faixa alterou pixels renderizados. Em 4.7.2 Forward+ D3D12, a demo padrão alterou 32 mil pixels nessa comparação.
