import { typescript } from 'projen';
const project = new typescript.TypeScriptProject({
  defaultReleaseBranch: 'main',
  name: 'lua-zombie-topdown-shooter',
  projenrcTs: true,
  up,
});
project.synth();