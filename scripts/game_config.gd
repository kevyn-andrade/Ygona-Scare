extends RefCounted
## Parametros de design do YGONA SCARE.
## Tudo que o GDD marca como [A DEFINIR] / [SUGESTAO] fica aqui para ajuste
## rapido, sem precisar mexer na logica em game.gd.

# --------------------------- ESCURIDAO / VISAO -----------------------------
const DARKNESS: float = 0.95              # opacidade do escuro fora do cone (1 = preto total)
const HOUSE_LIGHT_DARKNESS: float = 0.22  # escuro residual enquanto a casa ainda tem luz
const AMBIENT_RADIUS: float = 100.0       # halo (px) que a protagonista enxerga ao redor de si
const EYES_RANGE: float = 235.0           # distancia em que os olhos da entidade brilham no escuro (0 desliga)

# --------------------------- LANTERNA / BATERIA ----------------------------
const LIGHT_RANGE: float = 334.0
const LIGHT_RANGE_GHOST: float = 295.0
const LIGHT_HALF_ANGLE: float = 0.53      # radianos, com a bateria cheia
const CONE_FULL_ENERGY: float = 60.0      # acima deste %, o cone tem tamanho total
const CONE_MIN_RANGE: float = 0.48        # fracao do alcance com a bateria no fim
const CONE_MIN_ANGLE: float = 0.50        # fracao da abertura com a bateria no fim
const DRAIN_NORMAL: float = 0.95          # % por segundo
const DRAIN_GHOST: float = 8.2
const DRAIN_LIT_EXTRA: float = 0.65       # gasto extra enquanto paralisa a entidade
const RECHARGE_CAP: float = 30.0          # recarga "de emergencia" com a lanterna guardada
const RECHARGE_RATE: float = 6.0
const BATTERY_CHARGE: float = 45.0        # carga de cada pilha

# --------------------------- ENTIDADE --------------------------------------
const WAKE_DELAY: float = 7.0             # segundos entre a queda de luz e a entidade comecar a andar
const PATROL_SPEED: float = 85.0
const PATROL_SPEED_PER_FRAGMENT: float = 10.0
const SEARCH_SPEED: float = 127.0
const SEARCH_SPEED_PER_FRAGMENT: float = 11.0
const CHASE_SPEED: float = 173.0
const CHASE_SPEED_PER_FRAGMENT: float = 19.0
const LAUGH_COOLDOWN: float = 10.0        # intervalo minimo entre risadas

# Habilidades por fragmento [A DEFINIR no GDD]. Use 99 para desligar uma delas.
const ABILITY_BLACKOUT_AT: int = 1        # nº de fragmentos que libera "falhar a lanterna"
const ABILITY_TELEPORT_AT: int = 2        # nº de fragmentos que libera o teletransporte curto
const JAM_RANGE: float = 430.0            # distancia maxima para ela conseguir apagar a lanterna
const JAM_WARNING: float = 0.9            # tempo entre a risada de aviso e a falha
const JAM_SECONDS: float = 1.3            # duracao da falha (+0.35 s por fragmento extra)
const JAM_COOLDOWN_MIN: float = 13.0
const JAM_COOLDOWN_MAX: float = 21.0
const TELEPORT_COOLDOWN: float = 15.0
const TELEPORT_MIN_DIST: float = 280.0    # so teleporta se estiver mais longe que isso...
const TELEPORT_MAX_DIST: float = 760.0    # ...e mais perto que isso
const TELEPORT_KEEP: float = 190.0        # nunca reaparece mais perto que isso da jogadora

# --------------------------- FRAGMENTOS ------------------------------------
const PULSE_PERIOD: float = 4.6           # segundos entre pulsos com a entidade longe
const PULSE_PERIOD_NEAR: float = 1.5      # ... com a entidade colada
const PULSE_MIN_STRENGTH: float = 0.45    # forca do pulso com a entidade longe (1 = maximo)
const PULSE_DANGER_RANGE: float = 520.0   # distancia entidade-jogadora que intensifica os pulsos
const PULSE_HINT_RANGE: float = 1250.0    # ate onde o pulso aparece como brilho na borda da tela

# --------------------------- RITUAL / FLUXO --------------------------------
const RITUAL_SECONDS: float = 15.0
const INTRO_ENABLED: bool = true
const INTRO_SCENES: Array = [5.2, 5.6, 4.6, 3.0]  # duracao de cada quadro da abertura
const JUMPSCARE_SECONDS: float = 1.25
