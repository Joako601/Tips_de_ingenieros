import { execFileSync } from 'node:child_process';

// Los alcances son las carpetas de contenido (las lista scripts/carpetas.sh) más estos dos.
const carpetas = execFileSync('sh', [new URL('./scripts/carpetas.sh', import.meta.url).pathname], { encoding: 'utf8' })
  .split('\n')
  .filter(Boolean);

export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'scope-enum': [2, 'always', [...carpetas, 'repo', 'deps']],
    // Los cuerpos de Dependabot y las URLs de las referencias superan los 100 caracteres.
    'body-max-line-length': [0],
    'footer-max-line-length': [0],
  },
};
