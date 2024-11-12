import { awscdk } from 'projen';
const project = new awscdk.AwsCdkTypeScriptApp({
  cdkVersion: '2.166.0',
  defaultReleaseBranch: 'main',
  name: 'lua-zombie-topdown-shooter',
  projenrcTs: true,
  depsUpgrade: false,
});

project.synth();