Hola Claude. Necesito que programes una mecánica de generación procedural de mapa tipo Rogue-lite (estilo The Binding of Isaac) para nuestro juego Crystal Heart en Godot 4.

Ya he dejado listas las escenas preliminares en las carpetas correspondientes. Puedes agregar más en caso de ser necesario. Sigue las reglas de nomenclatura que el proyecto sigue, con variables, funciones o señales en inglés.

1. Modifica 'res://Stages/Layouts/Cave/main_cave.gd':
- Implementa un algoritmo de Drunkard's Walk que genere una disposición de salas/layouts orgánica (dejando espacios vacíos en la cuadrícula).
- Debe exponer variables @export para controlar la cantidad EXACTA de salas:
  * easy_room (int)
  * medium_room (int)
  * hard_room (int)
  * puzzle_room (int)
  * rest_room (int)
- Debe sumar de forma automática estas cantidades + 2 (Sala de Inicio y Sala de Jefe) para calcular el tamaño total del mapa.
- La Sala de Inicio siempre estará en (0,0). La Sala de Jefe debe colocarse en la coordenada más lejana (usando distancia Manhattan) o en la última generada para garantizar recorrido.
- El script debe crear una "bolsa" (Array) con los tipos de salas solicitados, mezclarla con shuffle() y vaciarla aleatoriamente sobre las coordenadas restantes del mapa.
- Debe instanciar la escena 'Layout1.tscn' en cada coordenada calculada, multiplicando la coordenada por el tamaño en píxeles de la sala.
- Al instanciar cada sala, debe revisar sus coordenadas vecinas (Norte, Sur, Este, Oeste) en el diccionario del mapa y llamar al método `configure_room()` de la sala pasándole el tipo de sala y los cuatro booleanos de conexión.

2. Modifica el script de la plantilla de sala ('res://Stages/Layouts/Layout1/layout_1.gd'):
- Implementa la función `configure_room(type: String, north: bool, south: bool, east: bool, west: bool) -> void`.
- Si un booleano de dirección es FALSE (no hay vecino), debe mantener VISIBLE y ACTIVA la colisión de la puerta correspondiente (NorthDoor, SoutDoor, etc.) para que actúe como un muro de contención.
- Si es TRUE (hay vecino), debe ocultar la puerta y desactivar su colisión usando set_deferred("disabled", true) para abrir el pasillo.
- Añade variables @export de tipo Array[PackedScene] para 'puzzle_list', 'rest_list' y los layouts internos de combate.
- Añade un diccionario o campos @export de tipo Array[SpawnCategory] para inyectar al componente 'EnemySpawner' las pools de enemigos correspondientes ("Easy_Combat", "Medium_Combat", "Hard_Combat", "Boss") según el tipo de sala recibido.
- Si el tipo es "Puzzle" o "Rest", debe elegir una escena al azar de sus respectivos arrays, instanciarla y añadirla como hija de 'ContenedorInterior', asegurándose de limpiar el 'EnemySpawner' para que no aparezcan enemigos en salas pacíficas.
- Dado que el 'EnemySpawner' original ejecuta el spawn en su _ready(), asegúrate de actualizar sus propiedades 'spawn_categories' y 'max_enemies' en este método ANTES o llamando manualmente a `spawn_all_categories()` si corresponde.

Por favor, realiza estas implementaciones de forma limpia y comprueba que no rompan las dependencias físicas ni los Singletons del juego.