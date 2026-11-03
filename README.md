# YGONA SCARE — jogo 2D de terror para Godot 4.7

Protótipo acadêmico jogável, em GDScript, com **perspectiva isométrica 45° (2.5D)**, criatura que congela sob luz branca, lanterna normal/espectral, três puzzles, perseguições e trilhas dinâmicas originais. Não é uma simples imagem ou vídeo: o ZIP contém um projeto editável do Godot.

## Rodar no Godot 4.7 / 4.7.2

1. Extraia o ZIP em uma pasta própria (não misture com a versão anterior).
2. No gerenciador do Godot, clique **Importar** e escolha `project.godot`.
3. Abra o projeto; selecione **2D** no topo do editor (a aba 3D mostra um espaço vazio mesmo para jogos 2D).
4. Pressione **F5** ou use **Executar Projeto**. Na tela de título, pressione **Enter**.
5. Caso o editor mantenha cache de uma versão antiga, feche o Godot e reabra o projeto na nova pasta.

### Controles

| Ação | Tecla |
|---|---|
| Movimentar na tela isométrica | W A S D / setas |
| Apontar lanterna | Mouse |
| Tirar lanterna do decote / guardar no decote | **Espaço** |
| Alternar luz normal / sobrenatural (lanterna ligada) | F |
| Interagir, esconder-se, atravessar Costura Espectral | E |
| Correr (gasta fôlego e faz barulho) | Shift |
| Arremessar objeto / distração | Q |
| Ver ajuda | H |
| Pausar | Esc |
| Reaparecer após morte / reiniciar após vitória | R ou Enter |

### Mudanças da versão original

- **Nome:** de `Entre as Paredes` para **Ygona Scare** em `project.godot`, árvore de cena, menu e HUD.
- **Câmera:** sistema 2.5D isométrico a 45°, com paredes de altura aparente e fachadas agora sempre opacas.
- **Protagonista:** personagem feminina procedural com cabelos longos e roupa roxa. Agora a lanterna desaparece completamente ao ser guardada, emerge do centro do decote por etapas e é erguida com a mão antes de acender. O gesto é estilizado, sem nudez.
- **Controles:** WASD acompanha os eixos visuais da perspectiva, e a mira do mouse é convertida das coordenadas da tela para as do mundo.
- **Entidade:** a criatura agora se chama **Ygona** dentro do jogo, representada como aparição abstrata. Ela fica paralisada somente sob **luz normal**, não sob luz espectral.
- **Áudio:** música dinâmica original de proximidade `assets/audio/ygona_theme.wav`, além de quatro camadas de ambiente que intensificam com cada fragmento.

## Como vencer

1. **Biblioteca** — use F para ler a inscrição espectral, depois ative os livros na ordem indicada. Colete a fotografia.
2. **Quarto** — ache a chave na **cozinha**. Use-a na caixa de música do quarto, atraindo a entidade, e colete a canção.
3. **Oficina** — revele a sequência de selos com a luz espectral e interaja com os três selos na ordem correta. Colete o reflexo.
4. **Vestíbulo** — retorne ao altar central, pressione E e sobreviva durante os 15 segundos do ritual.
5. Alcance a porta principal para ganhar.

As passagens roxas (Costuras Espectrais) podem ser atravessadas com E enquanto a lanterna está em modo espectral. Quando a carga estiver abaixo de 45%, ela pode ser recuperada desligando a lanterna (até 45%) ou recolhendo pilhas. Guardar a lanterna com carga superior a 45% não reduz a energia.

## Arquivos

```
project.godot
scenes/main.tscn
scripts/game.gd               # estado do jogo, puzzles, controles, colisão, IA, HUD
scripts/manor_map.gd          # mapa lógico, parede, movimento e AStarGrid2D
scripts/iso_renderer.gd       # câmera e projeção 45°, paredes e personagens
scripts/music_director.gd    # áudio por proximidade e progressão
assets/audio/*.wav            # trilhas e efeitos autorais de síntese
icon.png                      # ícone próprio

docs/visao_45_graus.png       # imagem conceitual ilustrativa
```

## Observações técnicas

- **Perspectiva:** pseudoisométrica 2:1 em geometria de desenho 2D; não é uma câmera 3D. A projeção não altera física ou AStar do mapa. Isso reduz complexidade e permite melhorar arte individualmente.
- **Arte:** vetorial/procedural; não há imagens de terceiros nem sprites copiados. O personagem e a entidade são visualmente ficcionais.
- **Performance:** o cenário estático é cacheado em imagens de piso e camadas de paredes opacas, e as faixas fora da área visível não são desenhadas. As entidades móveis continuam ordenadas por profundidade.
- **Comportamento da entidade:** patrulha, investigação, busca, perseguição e congelamento. O modo espectral atrai a criatura e não a paralisa.
- **Áudio:** músicas e efeitos sintetizados para esta versão; não são usados trechos de memes, vídeos reais ou voz de nenhuma pessoa.
- **Título:** referência cultural à influenciadora Ygona Moura; projeto de fã não oficial, não afiliado à sua família nem representante de sua imagem/voz. Caso seja publicado fora da disciplina, revisem também o uso do nome e eventuais direitos associados.
- **Testes:** o pacote pode ser revisado estaticamente neste ambiente, mas sem o executável do Godot 4.7 não foi possível assegurar uma partida completa em execução. Se houver erros apontados pelo Godot, compartilhem o Debugger para uma correção focada.

## Equipe: próximas melhorias

Substituir sprites procedurais por animações pixel art, polir a legibilidade de paredes, melhorar o áudio espacial, testar a dificuldade com colegas que não conhecem o mapa, e revisar o equilíbrio das três partes da campanha.

## Teste automático dentro do Godot (opcional)

Abra um terminal na pasta deste projeto e execute:

```bash
godot --headless --path . --script res://tests/smoke_test.gd
```

Se o executável não estiver no PATH, substitua `godot` pelo caminho do seu Godot 4.7.2. O teste instancia `main.tscn`, valida a conversão 2D↔isométrica e confere o caminho até os objetivos. Ele **não substitui** um teste visual e jogável com pessoas.

---

## Atualização de desempenho e animação — 03/11/2026

Esta revisão corrige três problemas observados no Godot 4.7.2:

1. **Paredes não ficam mais translúcidas perto da protagonista.** O comportamento antigo aplicava opacidade `0.26` às paredes próximas. Agora as fachadas permanecem sólidas; a projeção isométrica e as colisões não foram modificadas.
2. **Renderização mais econômica e fluida.** O piso de 53×37 tiles é pré-renderizado numa única textura, e as 644 paredes são organizadas em 89 camadas por profundidade. Na versão anterior, dezenas/centenas de polígonos eram reconstruídos a cada quadro, provocando lentidão em máquinas mais modestas. A nova versão desenha apenas as faixas de parede visíveis. A renderização usa resolução interna fixa de **1152×720**, ampliada pelo Godot quando a janela é maior; isto diminui o custo por quadro, embora a imagem possa parecer mais pixelizada em telas muito grandes.
3. **Nova animação para a lanterna.** Ao pressionar `Espaço`, a protagonista leva a mão à região central do decote, retira a lanterna, ergue o braço e aponta na direção do mouse. Ao pressionar novamente, realiza o movimento inverso e a lanterna deixa de aparecer — ela não fica mais presa visualmente na frente do peito. O efeito de iluminação só começa depois que o objeto é retirado. A animação leva aproximadamente 0,7 segundo.

Outras melhorias: movimento dos personagens interpolado entre passos de física (mais suave em monitores de 75/120/144 Hz), menos testes de colisão dos raios da luz, correção da perda de energia quando a lanterna era guardada com mais de 45% da bateria e opção **F3** para mostrar o FPS na tela. O jogo começa com a lanterna efetivamente guardada.

### Observações

- Para usar esta versão, **extraia o ZIP em uma nova pasta** e importe o `project.godot` dessa pasta. Não misture os arquivos com o projeto antigo.
- O renderizador utiliza as imagens geradas em `assets/render_cache/`; não apague essa pasta. Caso você altere a geometria ou a paleta em `manor_map.gd`/`iso_renderer.gd`, execute `python3 build_render_cache.py` (requer Pillow) para atualizar as texturas.
- Para verificar FPS, pressione **F3** durante a partida. Faça a comparação com a versão anterior no mesmo computador e com a mesma janela.
- O arquivo `tests/smoke_test.gd` passou a testar a presença do cache, o estado guardado da lanterna e a preservação da bateria, além da geometria e caminhos.
- **Limitação dos testes:** foi possível verificar estaticamente todos os assets e scripts, mas este ambiente não dispõe do binário Godot para uma execução gráfica ou para medir FPS real. É necessário abrir no Godot 4.7.2 e confirmar visualmente o resultado.
