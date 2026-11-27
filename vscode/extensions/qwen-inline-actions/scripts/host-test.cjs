// Temporary installed extension executes tests against the actual remote Extension Host.
const fs=require('node:fs');const os=require('node:os');const path=require('node:path');const cp=require('node:child_process');
const testVersion='0.0.1'; const testName='qwen-inline-actions-host-test-'+Date.now();
const root=path.resolve(__dirname,'..');const stage=fs.mkdtempSync(path.join(os.tmpdir(),'qwen-host-test-'));const ext=path.join(stage,'extension');fs.mkdirSync(ext);
fs.copyFileSync(path.join(root,'test/host.cjs'),path.join(ext,'host.cjs'));fs.cpSync(path.join(root,'dist'),path.join(ext,'dist'),{recursive:true});
fs.writeFileSync(path.join(ext,'test-config.json'),JSON.stringify({report:path.join(stage,'results.json'),sourceRoot:root}));
fs.writeFileSync(path.join(ext,'package.json'),JSON.stringify({name:testName,publisher:'local',version:testVersion,engines:{vscode:'^1.90.0'},extensionKind:['workspace'],activationEvents:['*'],main:'./host.cjs'}));
fs.writeFileSync(path.join(stage,'[Content_Types].xml'),'<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="json" ContentType="application/json"/><Default Extension="cjs" ContentType="application/javascript"/><Default Extension="js" ContentType="application/javascript"/><Default Extension="map" ContentType="application/json"/><Default Extension="vsixmanifest" ContentType="text/xml"/></Types>');
fs.writeFileSync(path.join(stage,'extension.vsixmanifest'),'<?xml version="1.0"?><PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011"><Metadata><Identity Language="en-US" Id="'+testName+'" Version="'+testVersion+'" Publisher="local"/><DisplayName>Qwen temporary host tests</DisplayName><Description xml:space="preserve">Temporary tests</Description><Properties><Property Id="Microsoft.VisualStudio.Code.Engine" Value="^1.90.0"/><Property Id="Microsoft.VisualStudio.Code.ExtensionKind" Value="workspace"/></Properties></Metadata><Installation><InstallationTarget Id="Microsoft.VisualStudio.Code"/></Installation><Dependencies/><Assets><Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true"/></Assets></PackageManifest>');
const vsix=path.join(stage,'host-test.vsix');cp.execFileSync('zip',['-qr',vsix,'.'],{cwd:stage});

cp.execFileSync('code',['--install-extension',vsix,'--force'],{stdio:'inherit'});

(async()=>{
  const reportPath=path.join(stage,'results.json');
  const deadline=Date.now()+45000;
  while(!fs.existsSync(reportPath) && Date.now()<deadline) await new Promise(r=>setTimeout(r,250));
  if(!fs.existsSync(reportPath)) {
    console.error('Tests have not completed. Use Developer: Reload Window; then inspect '+reportPath);
    console.error('Cleanup after completion: code --uninstall-extension local.'+testName);
    process.exitCode=1;return;
  }
  const report=JSON.parse(fs.readFileSync(reportPath,'utf8'));
  fs.writeFileSync(path.join(root,'.test-results.json'),JSON.stringify(report,null,2));
  console.log(JSON.stringify(report,null,2));
  cp.execFileSync('code',['--uninstall-extension','local.'+testName],{stdio:'inherit'});
  fs.rmSync(stage,{recursive:true,force:true});
  if(!report.passed)process.exitCode=1;
})().catch(error=>{console.error(error);process.exitCode=1;});
