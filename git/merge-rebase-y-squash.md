# *Merge*, *rebase* y *squash*

<!-- cspell:words Chacon Straub bisect oneline Politica Apress -->

> **Tipo de página:** explicación. Te ayuda a entender las tres formas de integrar una rama y qué historial deja cada una; no es una referencia de comandos.

## El problema

Cuando una rama termina, hay que traer sus cambios a `main`. Git ofrece varias formas de hacerlo, y cada una deja un historial distinto. Los equipos suelen elegir una por costumbre y después descubren las consecuencias: un historial lleno de commits "arreglo" y "ahora sí", un grafo con tantas líneas cruzadas que nadie lo puede leer, o una compañera que pierde trabajo porque alguien reescribió una rama compartida.

Alrededor de `rebase` hay además dos posturas extremas: "es peligroso y nunca debe usarse" y "hay que hacer *rebase* siempre, también de ramas compartidas". Las dos son incorrectas.

## La idea central

Hay tres formas principales de integrar una rama:

- ***Merge commit*.** Se crea un commit nuevo con dos padres: la punta de `main` y la punta de la rama. El historial conserva cada commit tal como se hizo y muestra el punto en que la rama se unió.
- ***Rebase* y avance rápido (*fast-forward*).** Los commits de la rama se vuelven a aplicar, uno por uno, encima de la punta actual de `main`. Git crea commits nuevos con el mismo contenido pero distinta identidad. Después `main` avanza hasta el último, y el historial queda lineal.
- ***Squash*.** Todos los cambios de la rama se combinan en un único commit nuevo sobre `main`. Los commits intermedios no llegan a `main`.

La regla que resuelve la discusión sobre `rebase` está en *Pro Git*, de Scott Chacon y Ben Straub: **no hagas *rebase* de commits que existen fuera de tu repositorio y sobre los que otras personas pueden haber basado su trabajo**. Reescribir tus commits locales antes de compartirlos es seguro. Reescribir commits que otra persona ya descargó la obliga a reconciliar dos versiones de la misma historia.

## Cómo se estructura

Partimos de una rama `feat/descuentos-pedido` con dos commits, mientras `main` recibió una corrección. Estos son los grafos reales que muestra `git log --graph --oneline` después de cada forma de integrar.

Con *merge commit* (`git merge --no-ff`):

```text
*   Merge branch 'feat/descuentos-pedido'
|\
| * test: prueba el descuento por volumen
| * feat: agrega PoliticaDeDescuento
* | fix: corrige el total con envío
|/
* feat: crea el pedido
```

Con *rebase* y avance rápido (`git rebase main` en la rama y después `git merge --ff-only` en `main`):

```text
* test: prueba el descuento por volumen
* feat: agrega PoliticaDeDescuento
* fix: corrige el total con envío
* feat: crea el pedido
```

Con *squash* (`git merge --squash` y un commit):

```text
* feat: agrega descuentos al pedido
* fix: corrige el total con envío
* feat: crea el pedido
```

GitHub ofrece las tres opciones al fusionar un *pull request*: el *merge commit* (la opción por defecto), *Squash and merge* y *Rebase and merge*. Cada repositorio puede habilitar solo algunas.

## Cuándo no usarlo

- ***Rebase* de ramas compartidas.** Si otra persona ya trabaja sobre tu rama, reescribirla rompe la regla de *Pro Git*. Integra con *merge* o coordina antes de reescribir.
- ***Squash* cuando los commits intermedios importan.** Si la rama tiene commits bien separados, cada uno con sentido propio (por ejemplo, un *refactor* y después la función nueva), el *squash* los junta en uno y se pierde esa separación.
- ***Merge commit* en ramas con commits de trabajo en progreso.** Si la rama está llena de commits "wip" y "arreglo", el *merge commit* los lleva todos a `main`. Conviene limpiarlos antes con un *rebase* interactivo local o integrar con *squash*.

## Qué se gana y qué se pierde

| Forma | Se gana | Se pierde |
| --- | --- | --- |
| *Merge commit* | Historial completo y fiel; no reescribe nada | Grafo con ramas cruzadas, difícil de leer cuando hay muchas |
| *Rebase* + avance rápido | Historial lineal que conserva cada commit | Reescribe commits: peligroso si la rama era compartida |
| *Squash* | Un commit por cambio en `main`, fácil de leer y de revertir | Se pierden los commits intermedios y su detalle |

## Confusiones frecuentes

- **"`git rebase` es peligroso y nunca debe usarse."** Es seguro sobre commits que solo existen en tu repositorio. *Pro Git* lo recomienda para dejar tu trabajo limpio antes de compartirlo.
- **"Hay que hacer *rebase* también de las ramas públicas para tener un historial lindo."** Es justo lo que la regla de *Pro Git* prohíbe. Un historial lineal no compensa el trabajo que pierde quien ya había descargado esos commits.
- **"Con *squash* se pierde la autoría de quien colaboró."** Se pierden los commits intermedios, pero los *trailers* `Co-authored-by` pueden pasar al mensaje del commit final. Este repositorio lo hace así y lo revisa al fusionar.
- **"El historial no importa, solo importa el código."** El historial es lo que usas para entender por qué cambió algo y para encontrar cuándo se rompió.

## Ejemplo

El historial cambia lo que puede hacer `git bisect`, el comando que busca por bisección el commit que introdujo un error.

Con **squash**, cada commit de `main` es un cambio completo que pasó la revisión y el CI. Si `bisect` señala `feat: agrega descuentos al pedido`, sabes qué *pull request* mirar, pero no cuál de sus pasos intermedios causó el problema.

Con **rebase**, `main` tiene todos los commits de la rama en línea. `bisect` puede señalar exactamente `feat: agrega PoliticaDeDescuento`. Para que eso funcione, cada commit intermedio tiene que compilar y pasar las pruebas. Si no, `bisect` se detiene en commits rotos que no tienen nada que ver con el error.

Con **merge commit**, `bisect` puede entrar en la rama y señalar un commit intermedio, o señalar el *merge commit* cuando el error aparece solo al combinar las dos líneas. La opción `git bisect start --first-parent` sigue solo el primer padre de cada *merge*: identifica el *merge* que introdujo el error e ignora los commits internos de la rama.

Este repositorio usa *squash and merge* como único método: cada *pull request* deja un commit en `main` con un título que sigue [Conventional Commits](conventional-commits.md) y con los *trailers* de coautoría.

## Referencias

- Chacon, S. y Straub, B. (2014). *Pro Git* (2.ª ed.). Apress. Sección 3.6, *Git Branching - Rebasing*. <https://git-scm.com/book/en/v2/Git-Branching-Rebasing> (consultado el 2026-10-27; [copia archivada](https://web.archive.org/web/20261009054303/https://git-scm.com/book/en/v2/Git-Branching-Rebasing)). Qué hace `rebase`, comparación con `merge` y la regla sobre no reescribir commits compartidos (*The Perils of Rebasing*).
- Chacon, S. y Straub, B. (2014). *Pro Git* (2.ª ed.). Apress. Sección 7.6, *Git Tools - Rewriting History*. <https://git-scm.com/book/en/v2/Git-Tools-Rewriting-History> (consultado el 2026-10-27; [copia archivada](https://web.archive.org/web/20261009203834/https://git-scm.com/book/en/v2/Git-Tools-Rewriting-History)). *Rebase* interactivo y *squash* de commits antes de compartirlos.
- Git (s. f.). *git-merge Documentation*. <https://git-scm.com/docs/git-merge> (consultado el 2026-10-27; [copia archivada](https://web.archive.org/web/20261016102710/https://git-scm.com/docs/git-merge)). Opciones `--no-ff`, `--ff-only` y `--squash`.
- Git (s. f.). *git-rebase Documentation*. <https://git-scm.com/docs/git-rebase> (consultado el 2026-10-27; [copia archivada](https://web.archive.org/web/20261020024621/https://git-scm.com/docs/git-rebase)). Referencia del comando.
- Git (s. f.). *git-bisect Documentation*. <https://git-scm.com/docs/git-bisect> (consultado el 2026-10-27; [copia archivada](https://web.archive.org/web/20261016132103/https://git-scm.com/docs/git-bisect)). Búsqueda por bisección y la opción `--first-parent`.
- GitHub (s. f.). *Pull request merges*. <https://docs.github.com/en/pull-requests/reference/pull-request-merges> (consultado el 2026-10-27; [copia archivada](https://web.archive.org/web/20261017011837/https://docs.github.com/en/pull-requests/reference/pull-request-merges)). Las tres formas de fusionar un *pull request* en GitHub.

Última revisión: 2026-10-27
