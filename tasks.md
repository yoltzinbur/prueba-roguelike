Actúa como un desarrollador experto en Godot 4 y GDScript. Vamos a implementar la lógica global para el segundo puzzle en "puzzle_laser.gd" basándonos en el Enfoque de Entradas Booleanas (A y B) utilizando los elementos existentes en la escena (Totem, Totem2, Receptor, Receptor2, Box, Box2, Box3 y Box4).

Por favor, implementa la estructura lógica bajo las siguientes condiciones, utilizando tipado estricto y la sintaxis de Godot 4:

1. Relación de Entradas (Tótem -> Receptor):
- 'Receptor' representa la entrada lógica A. Se considera ACTIVA (1) si el láser de 'Totem' lo está impactando. Si una caja bloquea el rayo, pasa a INACTIVA (0).
- 'Receptor2' representa la entrada lógica B. Se considera ACTIVA (1) si el láser de 'Totem2' lo está impactando. Si una caja bloquea el rayo, pasa a INACTIVA (0).
- Nota: Deja que la colisión física de las Cajas bloquee de forma natural el RayCast2D/Laser para cambiar este estado.

2. Modos de Operación Dinámicos (puzzle_laser.gd):
- Define un `enum LogicMode { AND, OR, XOR }`.
- Añade una variable interna `_current_mode: LogicMode`. Al igual que hicimos en el primer puzzle, este modo se sorteará aleatoriamente al instanciar la sala por primera vez (y se guardará en la persistencia del Layout para los reinicios).
- Tenemos 4 Box, las primeras 2 están lejos de los Totems, mientras que la 3 y la 4 están sobre los raycast del Totem y el Totem2 respectivamente. Al igual que las PressurePlate del primer puzzle, quita unas u otras según el caso, para evitar que el puzzle se complete apenas se inicie.

3. Evaluación de la Tabla de Verdad (`evaluate_puzzle()`):
En cada frame o cada vez que cambie el estado de los receptores, evalúa las señales A y B según el `_current_mode`:
- Modo AND: El puzzle se resuelve solo si A == true Y B == true (ambos láseres libres).
- Modo OR: El puzzle se resuelve si AL MENOS uno es true (A == true O B == true).
- Modo XOR (Variante Rogue-lite): El puzzle se resuelve SOLO si uno de los dos es true (A != B). Si AMBOS están activos (1 y 1), se considera una sobrecarga: debe invocar una función de penalización 'trigger_trap_or_enemies()' (por ejemplo, spawnear un enemigo de la cueva o disparar una trampa) y el puzzle permanece sin resolver.

4. Feedback Visual al Jugador:
- Instancia un Message desde la UI del Player que indique claramente el operador lógico actual ("COMPUERTA: AND", "COMPUERTA: OR", "COMPUERTA: XOR").
- Si el puzzle se resuelve con éxito, emite la señal correspondiente para abrir las puertas de la sala.

Inspecciona 'puzzle_laser.gd' y la estructura de la escena 'PuzzleLaser.tscn' para conectar correctamente las comprobaciones de los receptores sin romper la arquitectura de estados ni el sistema de reinicio del Layout.