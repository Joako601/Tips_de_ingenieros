export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'scope-enum': [2, 'always', ['arquitectura', 'principios', 'git', 'repo', 'deps']],
    // Los cuerpos de Dependabot y las URLs de las referencias superan los 100 caracteres.
    'body-max-line-length': [0],
    'footer-max-line-length': [0],
  },
};
