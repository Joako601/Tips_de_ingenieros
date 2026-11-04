# Validación por capas y prevención de inyecciones

<!-- cspell:words JPQL JPA Hibernate PedidoEntity PedidoRequest NotBlank parametrizar parametrizada parametrizadas parametrizado enlazados enlazar semántica semánticas sintáctica sintácticas lista-permitida inyecciones inyección -->

> **Tipo de página:** explicación. Te ayuda a separar qué se valida en cada capa de qué protege realmente contra una inyección; no es una guía de un *framework* concreto.

## El problema

Todo dato que cruza un límite de confianza (el cuerpo JSON, un parámetro de la URL, una cabecera, un archivo) puede llegar mal formado por error o manipulado a propósito. Si el servidor lo mezcla con un comando interno, como una consulta SQL, quien envía el dato puede cambiar lo que ese comando hace. Eso es una **inyección**.

El caso clásico es una búsqueda de pedidos por cliente. Si el código arma la consulta uniendo texto, la entrada `x' OR '1'='1` convierte un filtro por cliente en una consulta que devuelve todos los pedidos.

## La idea central

Hay dos defensas distintas que se confunden con frecuencia:

1. **Validación:** comprobar que el dato tiene la forma y el sentido que la aplicación espera. OWASP distingue la **sintaxis** (tipo y formato esperados) de la **semántica** (si el valor tiene sentido para la operación; su ejemplo es una reserva cuya fecha de fin debe ser posterior a la de inicio). Recomienda definir lo que se acepta y rechazar el resto (lista de permitidos), en lugar de intentar enumerar todo lo malicioso.
2. **Uso seguro del dato:** cómo se pasa el dato al intérprete que lo recibe. Para SQL, la defensa principal son las **consultas parametrizadas**: la estructura de la consulta va separada de los valores, que se enlazan por la API de la base de datos. Concatenar la entrada antes de preparar la consulta anula esa protección.

La validación no sustituye a la parametrización. OWASP lo dice sin rodeos: validar un valor no lo hace seguro para concatenarlo en SQL, y quitar caracteres de la entrada tampoco da parametrización ni codificación de salida.

## Cómo se estructura

La validación se reparte por capas, y cada capa comprueba lo que le toca:

| Capa | Qué comprueba | Ejemplo en pedidos |
| --- | --- | --- |
| Borde (adaptador web) | Formato y tamaño del dato, antes de usarlo | `clienteId` no vacío; la lista de líneas no supera un máximo |
| Dominio (`Pedido`) | Invariantes del negocio | un pedido no puede quedar sin líneas; la cantidad es positiva |
| Persistencia | Que el dato nunca forme parte de la estructura de la consulta | parámetros enlazados (`:clienteId`) |

Tres reglas de OWASP que sostienen ese reparto:

- **Validar siempre en el servidor.** Las comprobaciones del navegador dan respuesta rápida, pero se pueden saltar.
- **Poner límite de longitud** a las cadenas y limitar el tamaño de la petición antes de analizarla, para rechazar pronto lo desmesurado.
- **No intentar bloquear caracteres "peligrosos".** Bloquear un apóstrofo, por ejemplo, rechaza nombres válidos sin hacer segura una consulta.

Para SQL, la hoja de OWASP ordena las defensas: primero consultas preparadas; después, si se usan procedimientos almacenados, que no armen SQL dinámico por dentro; luego validación con lista de permitidos para lo que **no** puede parametrizarse (nombres de tablas o columnas, o `ASC`/`DESC`), eligiendo entre valores fijos que posee la aplicación; y el escapado manual al final, como la opción más débil.

## Cuándo no usarlo

- **Validar en el dominio lo que es solo formato.** Si un campo solo debe ser un número, la comprobación pertenece al borde; el dominio no debería conocer el JSON.
- **Duplicar en cada capa la misma comprobación.** Cada capa comprueba lo suyo; repetir las reglas de negocio en el controlador las deja desincronizadas.
- **Confiar solo en la validación.** Es la confusión principal; está más abajo.
- **Validar con listas de caracteres prohibidos.** Es frágil y rechaza entradas legítimas.

## Qué se gana y qué se pierde

| Se gana | Se pierde |
| --- | --- |
| Entradas desmesuradas o mal formadas se rechazan pronto | Código de validación que mantener en más de una capa |
| Las consultas parametrizadas hacen inofensiva una entrada hostil | Las partes dinámicas (orden, columnas) necesitan una lista cerrada de valores |
| Las invariantes del negocio viven en un solo sitio, el dominio | Hay que decidir qué errores se muestran al cliente |

## Confusiones frecuentes

- **"Como uso JPA / Hibernate o Entity Framework Core, soy inmune a la inyección SQL."** Un ORM no lo impide por sí solo. La hoja de OWASP advierte que las consultas de Hibernate pueden ser vulnerables a la inyección y aconseja enlazar los valores no confiables en lugar de concatenarlos. Armar `"FROM PedidoEntity p WHERE p.clienteId = '" + clienteId + "'"` es tan vulnerable como el SQL plano.
- **"Si valido la entrada, puedo concatenarla."** Validar un valor no lo hace seguro para concatenarlo en SQL. La validación reduce el abanico de entradas; la parametrización es lo que separa dato y comando.
- **"Escapar las comillas basta."** El escapado depende del dialecto y de la configuración de la base de datos; OWASP lo señala como la opción más débil y pide no usarlo en lugar del enlace de parámetros.
- **"Los procedimientos almacenados son seguros por definición."** Enlazar los argumentos protege la llamada, no el SQL dinámico que se arma dentro del procedimiento.
- **"Si el navegador ya valida el formulario, el servidor no tiene que hacerlo."** El atacante no usa tu formulario.

## Ejemplo

Dominio de pedidos. La comparación de SQL está comprobada en PostgreSQL 18.6 con una tabla de prueba; el código Java es ilustrativo y no está compilado.

Con una tabla de tres pedidos (`ana`, `luis` y `marta`) y la entrada `x' OR '1'='1`, la consulta armada con texto queda así y devuelve **las tres filas**:

```sql
SELECT id, cliente_id FROM pedidos WHERE cliente_id = 'x' OR '1'='1'
```

La misma entrada enlazada como parámetro es solo un valor que no coincide con ningún cliente y devuelve **cero filas**:

```sql
PREPARE por_cliente(text) AS
  SELECT id, cliente_id FROM pedidos WHERE cliente_id = $1;
EXECUTE por_cliente('x'' OR ''1''=''1');
```

En Java con JPA, la versión vulnerable concatena y la corregida enlaza el parámetro:

```java
// Vulnerable: la entrada pasa a formar parte de la consulta
var peligrosa = em.createQuery(
    "FROM PedidoEntity p WHERE p.clienteId = '" + clienteId + "'", PedidoEntity.class);

// Corregida: la entrada es un valor enlazado
var segura = em.createQuery(
    "FROM PedidoEntity p WHERE p.clienteId = :clienteId", PedidoEntity.class)
    .setParameter("clienteId", clienteId);
```

El borde valida formato y tamaño; el dominio valida las reglas del negocio:

```java
record PedidoRequest(
    @NotBlank String clienteId,
    @Size(min = 1, max = 100) List<LineaRequest> lineas) {}

// en el dominio
Pedido(String clienteId, List<Linea> lineas) {
    if (lineas.isEmpty()) {
        throw new IllegalArgumentException("Un pedido necesita al menos una línea");
    }
    // ...
}
```

Para un orden dinámico (`?orden=fecha`), el valor no se pega en la consulta: se elige entre una lista cerrada que posee la aplicación (`"fecha"` → `p.creadoEn`, `"total"` → `p.total`) y cualquier otro valor se rechaza. En .NET 8 la estructura es la misma, con consultas parametrizadas en EF Core o en `SqlCommand`.

## Referencias

- OWASP (s. f.). *SQL Injection Prevention Cheat Sheet*. <https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html> (consultado el 2026-11-04). Orden de las defensas: consultas preparadas, procedimientos almacenados, validación con lista de permitidos y escapado; advertencia sobre Hibernate.
- OWASP (s. f.). *Input Validation Cheat Sheet*. <https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html> (consultado el 2026-11-04). Validación sintáctica y semántica, lista de permitidos, validación en el servidor, límites de longitud y la validación como defensa que no sustituye a la parametrización.

Última revisión: 2026-11-04
