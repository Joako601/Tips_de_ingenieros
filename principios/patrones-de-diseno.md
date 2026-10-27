# Patrones de diseño

<!-- cspell:words Vlissides Notificador notificador Auditado envuelto Creacionales instanciar Politica patternitis maximo Ishikawa Silverstein -->

> **Tipo de página:** explicación. Te ayuda a entender qué es un patrón de diseño y cuándo conviene usar uno; no es un catálogo de los 23 patrones.

## El problema

Muchos problemas de diseño se repiten de un proyecto a otro: elegir entre varias formas de calcular algo, crear objetos sin atar el código a una clase concreta, agregar comportamiento a un objeto sin modificarlo. Sin un vocabulario común, cada equipo reinventa la solución y la explica desde cero en cada revisión de código.

El problema opuesto también existe: usar patrones porque sí. Un servicio de diez líneas termina envuelto en una fábrica, una estrategia y un *builder* que nadie necesitaba.

## La idea central

Un **patrón de diseño** describe un problema que aparece una y otra vez en un contexto dado y el núcleo de una solución que se puede aplicar muchas veces sin escribirla nunca igual.

La idea viene de la arquitectura de edificios. Christopher Alexander y sus colegas publicaron en 1977 *A Pattern Language*, un conjunto de patrones para diseñar ciudades y casas. En 1994, Erich Gamma, Richard Helm, Ralph Johnson y John Vlissides (conocidos como *Gang of Four* o GoF) llevaron esa forma de trabajar al diseño orientado a objetos y catalogaron 23 patrones.

En el libro de GoF cada patrón tiene cuatro elementos esenciales:

- **Nombre:** una o dos palabras que permiten hablar de diseño a un nivel más alto ("aquí va un *Decorator*").
- **Problema:** cuándo aplicarlo y en qué contexto.
- **Solución:** los elementos del diseño y cómo colaboran, descritos de forma abstracta, no como código para copiar.
- **Consecuencias:** qué se gana y qué se pierde al aplicarlo.

El valor principal de un patrón no está en el código, sino en las consecuencias: te dice qué precio pagas por la flexibilidad que obtienes.

## Cómo se estructura

GoF agrupa los patrones según su propósito:

| Grupo | Qué resuelve | Uno útil en backend |
| --- | --- | --- |
| Creacionales | Cómo se crean los objetos | *Factory Method*: una subclase o una implementación decide qué clase concreta instanciar |
| Estructurales | Cómo se combinan clases y objetos | *Decorator*: envolver un objeto para agregarle responsabilidades sin modificarlo |
| De comportamiento | Cómo se reparten responsabilidades y algoritmos | *Strategy*: encapsular cada variante de un algoritmo detrás de una interfaz común |

La página de [SOLID](solid.md) ya muestra un *Strategy*: `PoliticaDeDescuento` permite agregar descuentos nuevos sin modificar `ServicioDePedidos`. El ejemplo de esta página muestra un *Decorator*.

## Cuándo no usarlo

- **Cuando la flexibilidad no se necesita hoy.** Los propios autores de GoF advierten que los patrones no deben aplicarse indiscriminadamente: suelen lograr flexibilidad agregando niveles de indirección, y eso complica el diseño. Si solo existe un tipo de descuento, una interfaz con una única implementación es costo sin beneficio (ver [YAGNI](dry-kiss-yagni.md)).
- **Cuando el lenguaje ya lo resuelve.** Varios patrones de 1994 cubren carencias de C++ y Smalltalk de esa época. En Java 21 una estrategia sin estado puede ser una lambda (`Function<Pedido, BigDecimal>`), y en C# un delegado.
- **Para mostrar que conoces patrones.** Si quien lee el código tiene que reconocer el patrón para entender un caso simple, el diseño quedó más difícil de lo necesario.

## Qué se gana y qué se pierde

| Se gana | Se pierde |
| --- | --- |
| Vocabulario común: "es un *Decorator*" reemplaza un párrafo de explicación | Más clases e interfaces que leer |
| Soluciones probadas, con sus consecuencias ya documentadas | Indirección: seguir una llamada exige saber qué objeto real hay detrás |
| Puntos de extensión donde el cambio es probable | Si el cambio nunca llega, la flexibilidad fue costo sin beneficio |

## Confusiones frecuentes

- **"Un buen diseño usa la mayor cantidad posible de patrones."** Cada patrón resuelve un problema concreto y tiene un costo. Aplicarlos sin ese problema es lo que a veces se llama *patternitis*. Un diseño bueno usa los patrones que el problema pide, ni más ni menos.
- **"Un patrón es código que se copia."** GoF describe la solución en abstracto. Dos implementaciones del mismo patrón pueden verse muy distintas según el lenguaje y el contexto.
- **"Cualquier método estático `crear()` es el patrón *Factory*."** El *Factory Method* de GoF delega en una subclase o implementación la decisión de qué clase crear. Un método estático que construye un objeto es útil, pero es otra cosa.
- **"Los patrones de GoF son todos los patrones."** Hay catálogos para otras escalas: patrones de arquitectura empresarial, de integración entre sistemas o de sistemas distribuidos.

## Ejemplo

Dominio de pedidos con Java 21. El código compila y no depende de ningún *framework*.

El servicio de pedidos usa el puerto `NotificadorDeClientes`, como en la página de [arquitectura hexagonal](../arquitectura/hexagonal.md). Ahora se necesita reintentar los envíos que fallan y dejar un registro de auditoría, sin modificar el adaptador de correo ni el servicio.

Cada *Decorator* implementa la misma interfaz que el objeto que envuelve y le delega el trabajo, agregando su propia responsabilidad antes o después:

```java
public interface NotificadorDeClientes {
    void pedidoConfirmado(Pedido pedido);
}

public class NotificadorConReintentos implements NotificadorDeClientes {
    private final NotificadorDeClientes envuelto;
    private final int maximoDeIntentos;

    public NotificadorConReintentos(NotificadorDeClientes envuelto, int maximoDeIntentos) {
        this.envuelto = envuelto;
        this.maximoDeIntentos = maximoDeIntentos;
    }

    @Override
    public void pedidoConfirmado(Pedido pedido) {
        for (int intento = 1; ; intento++) {
            try {
                envuelto.pedidoConfirmado(pedido);
                return;
            } catch (RuntimeException e) {
                if (intento == maximoDeIntentos) {
                    throw e;
                }
            }
        }
    }
}

public class NotificadorAuditado implements NotificadorDeClientes {
    private final NotificadorDeClientes envuelto;
    private final List<String> registro;

    public NotificadorAuditado(NotificadorDeClientes envuelto, List<String> registro) {
        this.envuelto = envuelto;
        this.registro = registro;
    }

    @Override
    public void pedidoConfirmado(Pedido pedido) {
        envuelto.pedidoConfirmado(pedido);
        registro.add("Notificado el pedido " + pedido.id());
    }
}
```

Los decoradores se combinan al armar el objeto. El servicio sigue recibiendo un `NotificadorDeClientes` y no sabe cuántas capas tiene:

```java
NotificadorDeClientes notificador =
        new NotificadorAuditado(new NotificadorConReintentos(new NotificadorPorCorreo(), 3), registro);
```

El orden define qué ve cada capa: aquí la auditoría envuelve a los reintentos, así que ve una sola llamada por pedido, sin importar cuántos intentos hicieron falta por dentro.

Este reintento es deliberadamente simple: no espera entre intentos. En producción conviene una biblioteca de resiliencia como Resilience4j (Java) o Polly (.NET), que aplican la misma idea de envolver una llamada. En C# con .NET 8 el patrón se escribe igual, y el contenedor de dependencias permite registrar la cadena de decoradores.

## Referencias

- Gamma, E., Helm, R., Johnson, R. y Vlissides, J. (1994). *Design Patterns: Elements of Reusable Object-Oriented Software*. Addison-Wesley. ISBN 978-0-201-63361-0. Cap. 1: definición de patrón y sus cuatro elementos, clasificación por propósito y advertencia sobre no aplicarlos indiscriminadamente. Catálogo: *Factory Method*, *Decorator* y *Strategy*.
- Alexander, C., Ishikawa, S. y Silverstein, M. (1977). *A Pattern Language: Towns, Buildings, Construction*. Oxford University Press. Origen de la idea de lenguaje de patrones, que GoF cita como antecedente.

Última revisión: 2026-10-27
