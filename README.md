# AFRODITE SCARE — jogo 2D de terror para Godot 4.7

**História:** uma seita tentou trazer a deusa **Afrodite** de volta por meio de bruxaria. O ritual ficou incompleto, e o que atravessou foi só metade dela: uma Afrodite rachada e apodrecida, que só anda quando ninguém a vê. Para se completar, ela guarda as oferendas tiradas de três mulheres sacrificadas no altar. Devolver essas oferendas ao altar desfaz a invocação.

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
| Movimentar na tela isométrica | Setas ↑ ↓ ← → |
| Apontar lanterna | Mouse (só o mouse; as setas nunca giram o facho) |
| Tirar lanterna do decote / guardar no decote | **Espaço** |
| Alternar luz normal / sobrenatural (lanterna ligada) | F |
| Interagir, esconder-se, atravessar Costura Espectral | E |
| Correr (gasta fôlego e faz barulho) | Shift |
| Arremessar objeto / distração | Q |
| Ver ajuda | H |
| Pausar | Esc |
| Reaparecer após morte / reiniciar após vitória | R ou Enter |

> **Touchpad parado enquanto anda?** A lanterna segue só o mouse, então dá para andar para um lado e iluminar o outro. Muitos sistemas (GNOME/Fedora, Windows) bloqueiam o touchpad enquanto uma tecla está pressionada; nesse caso, use um mouse ou desligue o bloqueio. No GNOME: `gsettings set org.gnome.desktop.peripherals.touchpad disable-while-typing false`. No Windows 11: Configurações → Bluetooth e dispositivos → Touchpad → Toques → sensibilidade "Mais sensível".

### Mudanças da versão original

- **Nome:** de `Entre as Paredes` para **Afrodite Scare** em `project.godot`, árvore de cena, menu e HUD.
- **Câmera:** sistema 2.5D isométrico a 45°, com paredes de altura aparente e fachadas agora sempre opacas.
- **Protagonista:** personagem feminina procedural com cabelos longos e roupa roxa. Agora a lanterna desaparece completamente ao ser guardada, emerge do centro do decote por etapas e é erguida com a mão antes de acender. O gesto é estilizado, sem nudez.
- **Controles:** as setas do teclado (↑ ↓ ← →) acompanham os eixos visuais da perspectiva, e a mira do mouse é convertida das coordenadas da tela para as do mundo.
- **Entidade:** a criatura é **Afrodite pela metade**, a deusa trazida por um ritual de bruxaria que não terminou. Ela fica paralisada somente sob **luz normal**, não sob luz espectral.
- **Áudio:** música dinâmica original de proximidade `assets/audio/afrodite_theme.wav`, além de quatro camadas de ambiente que intensificam com cada fragmento.

## Como vencer

1. **Biblioteca** — use F para ler a inscrição espectral, depois ative os livros na ordem indicada. Pegue o silicone de Dalva.
2. **Quarto** — ache a chave na **cozinha**. Use-a na caixa de música do quarto, atraindo a entidade, e pegue o silicone de Marlene.
3. **Oficina** — revele a sequência de selos com a luz espectral e interaja com os três selos na ordem correta. Pegue o silicone de Soraia.
4. **Vestíbulo** — retorne ao altar central, pressione E para devolver os três silicones e sobreviva durante os 15 segundos do ritual.
5. Alcance a porta principal para ganhar.

A luz espectral abre dois tipos de passagem que **Afrodite não consegue usar**:

- **Paredes Espectrais** — dois trechos de parede (de dois blocos) que se atravessam andando: **salão ↔ quarto** e **vestíbulo ↔ oficina**. Com a luz normal parecem paredes comuns, com uma costura fina e um fiapo de fumaça roxa; com a luz espectral acesa viram um bloco lilás translúcido.
- **Costuras Espectrais** — rasgos costurados no ar que levam, com E, para o outro lado de uma parede grossa (biblioteca ↔ quarto, cozinha ↔ oficina, quarto ↔ vestíbulo). Custam 9% de carga.

Com a lanterna guardada, a carga se recupera sozinha só até 30%; acima disso, só com pilhas.

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
- **Cenário por cômodo:** cada cômodo tem piso e paredes próprios — biblioteca (tábuas, papel verde com arabescos, lambri, tapete verde), cozinha (ladrilhinho encardido, azulejo de metrô), quarto (tábuas, papel listrado com quadros, tapete persa), oficina (cimento com manchas, tijolo aparente), salão (mármore, papel bordô com filetes dourados, arandelas, passadeira até o altar), vestíbulo (xadrez preto e branco, lambri de madeira) e corredores (tábuas gastas, reboco descascando). Móveis e objetos são montados em volume: mesas com pernas e tampo de tábuas, estantes com lombadas, bancadas com portas e inox, cama com cabeceira e travesseiros, penteadeira com espelho oval, altar de pedra entalhado, guarda-roupas, atris com livro aberto, caixa de música com bailarina, chave, selos de pedra, envelope lacrado, vaso com flores murchas, pilhas e garrafa.
- **Refazer o cache do cenário:** depois de mudar `bake_floor`/`bake_wall` em `iso_renderer.gd`, rode `godot --path . --script res://tools/bake_scenery.gd` (abre uma janela) e em seguida `godot --headless --path . --import`.
- **Performance:** o cenário estático é cacheado em imagens de piso e camadas de paredes opacas, e as faixas fora da área visível não são desenhadas. As entidades móveis continuam ordenadas por profundidade.
- **Comportamento da entidade:** patrulha, investigação, busca, perseguição e congelamento. O modo espectral atrai a criatura e não a paralisa.
- **Áudio:** músicas e efeitos sintetizados para esta versão; não são usados trechos de memes, vídeos reais ou voz de nenhuma pessoa.
- **Título:** Afrodite é uma figura da mitologia grega (domínio público). A versão do jogo é uma releitura original e fictícia; o projeto não faz referência a nenhuma pessoa real.
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

---

## Atualização GDD — 10/11/2026

Implementação dos itens do GDD que faltavam no protótipo. Todos os valores de design ficam em `scripts/game_config.gd`.

| GDD | O que mudou |
|---|---|
| 3.2 Visão limitada | Fora do cone da lanterna a tela fica escura (`DARKNESS`). A luz respeita paredes; a protagonista enxerga só um pequeno halo ao redor de si. |
| 3.3 Entidade | Jumpscare (imagem + áudio) no game over: o rosto bate na tela em 0,12 s, escuro, tremendo aos saltos, com chiado de TV (`shaders/jumpscare.gdshader` + `assets/audio/static.wav`), faixas rasgadas, aberração cromática e quadros em que o sinal cai. Risada ao iniciar a perseguição. Olhos visíveis no escuro quando ela está muito perto. |
| 3.3 Habilidades | 1 fragmento: ela faz a lanterna **falhar** por instantes (a risada avisa antes). 2 fragmentos: **teletransporte curto** fora da luz. Ambas configuráveis/desligáveis. |
| 3.4 Bateria | Alcance **e abertura** do cone encolhem abaixo de 60% de carga. A recarga com a lanterna guardada agora vai só até 30%. |
| 3.5 Luz especial | A luz espectral (F) só é liberada ao pegar a **lente** no salão, depois do básico. |
| 3.6 Fragmentos | Pulsam de tempos em tempos, visíveis no escuro (fora da tela, um clarão na borda aponta a direção). Pulsos mais fortes e frequentes com a entidade perto. |
| 2.3 / 3.7 Abertura | Animação inicial (chegada de carro, vislumbre, fragmentos), vestíbulo **trancado e ainda iluminado**, carta sobre a invocação, bilhete, chave sob o vaso, vultos, e **queda de luz** ao abrir a porta. A entidade só desperta alguns segundos depois, anunciada pela risada. |
| 5.2 Áudio | Camada ambiente mais alta e acelerada a cada fragmento; efeitos não se cortam mais. |

### Arquivos novos

```
scripts/game_config.gd     # parâmetros de design ([A DEFINIR] / [SUGESTÃO] do GDD)
scripts/draw_layer.gd      # camada de desenho (mundo e máscara de luz)
shaders/darkness.gdshader  # escuridão recortada pela máscara de luz
tools/build_audio.py       # sintetiza laugh.wav, jumpscare.wav, blackout.wav
tests/visual_check.gd      # captura telas de vários momentos para revisão
```

- **Áudio da entidade:** `assets/audio/laugh.wav` e `jumpscare.wav` são sintetizados. Para usar outro áudio, substitua os arquivos mantendo os nomes.
- **Mapa:** o vestíbulo ganhou uma parede com porta (`ManorMap.FOYER_DOOR`); o cache de paredes foi regenerado (658 blocos).
- **Capturas:** `godot --path . --script res://tests/visual_check.gd -- <pasta>` abre o jogo por alguns segundos e grava PNGs.

---

## Atualização macabra — 16/11/2026

| Tema | O que mudou |
|---|---|
| Protagonista | Redesenhada (adulta, vestida, sem nudez): busto mais proeminente, cintura marcada, colo à mostra no decote em V, respiração e marcha natural (quadril para a perna de apoio, ombros em contraposição, transição suave entre parar/andar/correr). O busto, grande e em forma de gota, tem física de mola amortecida: acompanha o passo com atraso, quica ao parar ou arrancar e balança quando a lanterna é tirada ou guardada. A lanterna sobe **por trás** do busto, que se afasta enquanto ela passa, e só então é erguida e apontada. Ao guardar, o gesto se inverte. |
| Artefatos | Os três "fragmentos" agora são os **silicones das mulheres oferecidas a Afrodite no altar da seita** — Dalva (biblioteca), Marlene (caixa de música) e Soraia (espelho), personagens fictícias. São próteses de gel que tremem e pulsam; ao pegar cada uma, abre-se a etiqueta com a história da vítima, e ela vai para o decote junto da lanterna. No código continuam se chamando `fragment_*`. |
| Afrodite | Deusa pela metade, deformada porque o ritual não terminou: mármore rachado, como se tivesse apodrecido no fundo do mar. Concha de Vênus partida como auréola, cabelo encharcado até os quadris, túnica grega em farrapos pingando água preta com algas, peito aberto e costurado, braços de estátua com unhas pretas compridas que se estendem na perseguição e pescoço quebrado que estala mesmo sob a luz. Metade do rosto ainda é bela (lábio pintado, cílios, esclera preta), a outra metade é osso, com a boca rasgada até a orelha. O mesmo rosto aparece no jumpscare (maxilar despencando, mãos de mármore fechando pelos lados), no menu e na tela de morte. Criatura fictícia, sem reproduzir o rosto de ninguém. |
| Altar e ritual | Altar ensanguentado, com velas que seguram um resto de luz no escuro. No ritual, os silicones aparecem sobre o tampo e as três mulheres se erguem em volta para levar Afrodite de volta ao mar. |
| Pavor | Batimento cardíaco e vinheta vermelha que aceleram com a proximidade; sussurros das vítimas; rastro de sangue que a entidade deixa e que seca aos poucos (dá para rastreá-la com a lanterna); quatro frases escritas pelas vítimas, visíveis só na luz espectral. |
| Correções | O tremor de câmera existia no código mas nunca era aplicado — agora treme na queda de luz e ao pegar um silicone. Caixas de aviso medem o texto de verdade (frases longas não vazam mais). Tela de vitória mostra quantas vezes você morreu. |

- **Parâmetros novos** em `scripts/game_config.gd` (seção PAVOR): `HEART_RANGE`, `WHISPER_MIN/MAX`, `TRAIL_SPACING`, `TRAIL_SECONDS`.
- **Áudio novo** (sintetizado por `tools/build_audio.py`): `heartbeat.wav` e `whisper.wav`.
- **Testes:** `smoke_test.gd` cobre a etiqueta dos silicones, o rastro e o pavor; `visual_check.gd` grava closes do gesto da lanterna, de Afrodite e do ritual, e não move mais o cursor do mouse.

---

## Atualização de terror — 16/11/2026 (parte 2)

Tudo abaixo é ajustável na seção **ASSOMBRAÇÕES** de `scripts/game_config.gd`.

| Tema | O que mudou |
|---|---|
| Trilha de fundo | `assets/audio/lullaby.wav`: tema **original** de caixinha de música — agudo, repetitivo, em 6/8, com duas vozes desafinadas batendo uma na outra. Toca o tempo todo; fica mais lento e grave a cada silicone, e a "fita mastiga" quando Afrodite se aproxima. **Quando a música se cala de repente, tem algo parado no escuro.** Não é a música de Lavender Town (composição protegida); para usar outra faixa a que você tenha direito, substitua o arquivo mantendo o nome. |
| Aparições falsas | De tempos em tempos uma Afrodite falsa fica parada fora da luz, com os mesmos olhos da verdadeira. Iluminada ou tocada, ela estoura: a lanterna falha, a imagem rasga e às vezes um rosto pisca na tela. |
| A luz não segura para sempre | Enquanto ela está congelada, a **sombra dela rasteja pelo chão** até você. Se alcançar, a lanterna apaga por um instante. É preciso recuar, não só apontar. |
| Esconderijo | De dentro do armário só se vê pelas frestas — e, se ela estiver perto, um olho passa do outro lado procurando. **Entrar no armário com ela te vendo não funciona:** ela vai até lá e te tira. |
| Manequins da oficina | Só andam quando a luz não está neles. Param na beira do seu halo, com a cabeça virada para você e um braço apontando. Não ferem. |
| As três penduradas | Dalva, Marlene e Soraia estão embrulhadas em lençóis e penduradas no salão. Balançam mais quando iluminadas; de perto, dá para ver os olhos. Somem quando Afrodite é levada. |
| Perseguição | Ela avança aos trancos, como um filme com quadros faltando. |
| A casa | Rangidos, batidas na parede e coisas sendo arrastadas, em intervalos aleatórios. Ficar parada no escuro faz passos se aproximarem por trás, e alguém respira. |
| Imagem | Filtro de pavor (`shaders/fear.gdshader`): granulado de filme, vinheta, cores drenadas e aberração cromática que pioram com a proximidade dela. |
| Cenário | Marcas de arrasto até o altar, mãos ensanguentadas e recados escritos no assoalho; alguma coisa respirando debaixo do lençol da cama; bancadas de açougue e ganchos na cozinha. |

- **Áudio novo** (`tools/build_audio.py`): `lullaby`, `creak`, `knock`, `scrape`, `breath`, `sting`.
- **Dificuldade:** a sombra rastejante e o esconderijo comprometido deixam o jogo mais difícil. Para suavizar, aumente `SHADOW_MIN_SECONDS` / diminua `SHADOW_SPEED`, ou reduza `HIDE_SEEN_RANGE`.

### Distorção da trilha

A caixinha de música passa por um barramento próprio (`Caixinha`) com efeitos controlados em `update_theme` (`scripts/music_director.gd`):

- **Ao contrário:** conforme Afrodite se aproxima, a melodia normal cede lugar a `lullaby_reverse.wav`, a mesma faixa invertida e um pouco mais grave — as duas nunca afinam.
- **Apodrecendo:** o som racha (bitcrush), enjoa (phaser), afunda (filtro com ressonância) e ganha eco e reverberação. A cada silicone fica um pouco pior de forma permanente.
- **Mergulhos:** com ela perto, a altura escorrega de repente e volta devagar.
- **Disco engasgado:** nos sustos (aparição, sombra na lanterna, falha de luz) a música repete o mesmo pedaço cada vez mais rápido.
- **Fita parando:** antes de uma aparição falsa a música não corta mais — ela despenca de altura até o silêncio.
- Um limitador no fim da cadeia impede que a saída estoure.

Se trocar `lullaby.wav` por outra faixa, rode `python3 tools/build_audio.py` só se quiser regenerar a original; para a sua, gere também a versão invertida (no Audacity: Efeitos → Inverter no tempo) e salve como `lullaby_reverse.wav`. `tests/audio_probe.gd` mostra os níveis de cada estágio.

---

## Atualização de controle, colisão e luz espectral — 18/11/2026

| Tema | O que mudou |
|---|---|
| Lanterna | A mira segue **só o mouse**. Antes, com o mouse parado, a lanterna girava para a direção do passo, e mouse e setas brigavam pelo facho; agora dá para andar para um lado e iluminar o outro. |
| Colisão | A protagonista **não atravessa mais os objetos**: mesas, estantes, bancadas, cama, penteadeira, altar, guarda-roupas, atris, caixa de música, porta da frente, manequins e as penduradas. As pegadas ficam em `_build_solids()` (`scripts/game.gd`). A entidade continua passando pelos móveis. A ponta da Costura do quarto saiu de dentro da cama e foi para (4, 19). |
| Luz espectral | Ganhou poder de verdade: **Paredes Espectrais** (`ManorMap.SPECTRAL_PASSAGES`) em dois trechos de dois blocos, salão ↔ quarto e vestíbulo ↔ oficina. Na luz normal: parede comum, costura fina e fumaça roxa vazando (e um brilho miúdo visível no escuro). Na luz espectral: bloco **lilás translúcido** que se atravessa andando e deixa o facho passar. Afrodite não as usa: espera na boca da passagem. Se a luz falhar no meio da travessia, a protagonista ainda consegue sair. |
| Indicação das passagens | As Costuras Espectrais aparecem como um rasgo costurado no ar, com um círculo de runas no piso e um fio costurado no chão até a outra ponta. Na luz espectral, passagens próximas brilham sozinhas mesmo fora do facho; na luz normal, uma cicatriz costurada no chão e um fiapo de fumaça roxa denunciam o lugar. Avisos aparecem na primeira vez que ela chega perto de uma Parede Espectral. |
| As penduradas | Corpo com forma de gente, enrolado num lençol encharcado: pescoço quebrado com a cabeça tombada, rosto cinzento de olhos arregalados aparecendo pelo rasgo (de perto, as pupilas seguem você), boca aberta, cabelo molhado escapando, braço roxo caído com sangue pingando dos dedos, pés arroxeados, poça com respingos e moscas. Sob a luz, convulsionam por instantes. |
| Manequins | Cabeça de gesso rachada, órbitas fundas com uma brasa vermelha de perto e boca costurada que estica num sorriso; peito aberto em Y e costurado, ainda sangrando; alfinetes espetados, fita métrica no pescoço; um braço quebrado ao contrário e o outro, articulado, que sobe devagar e aponta para você com um dedo comprido de unha preta. Fora do halo, os que saíram do lugar mostram dois olhinhos acesos no escuro. |

- **Cache do cenário:** as células das Paredes Espectrais ficam fora das texturas de parede e são desenhadas a cada quadro. Foram refeitos `floor.png` e as faixas `d37–d39` e `d63–d65`.
- **Testes:** `smoke_test.gd` cobre a mira só no mouse, a colisão com o altar, a Parede Espectral fechada e aberta, a saída com a luz apagada no meio e a rota da entidade, que nunca passa por elas. `visual_check.gd` grava `27_parede_espectral_normal`, `28_parede_espectral_lilas` e `29_costura_espectral`.
