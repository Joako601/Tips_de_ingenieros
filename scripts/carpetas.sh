#!/bin/sh
# Imprime las carpetas de contenido, una por línea: las carpetas de la raíz que no son ocultas
# ni de herramientas. Es la única fuente de verdad de los alcances de commit, del check del
# título del PR y del check de referencias: para dar de alta un apartado basta con crear la carpeta
# y añadirla al índice del README.
#
# Es POSIX a propósito: lo ejecutan commitlint (dentro de un contenedor) y los workflows.
cd "$(dirname "$0")/.." || exit 1
for d in */; do
  d=${d%/}
  case "$d" in
    node_modules|scripts) continue ;;
  esac
  printf '%s\n' "$d"
done
