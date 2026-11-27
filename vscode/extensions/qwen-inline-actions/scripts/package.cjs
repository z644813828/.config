const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const cp = require('node:child_process');
const root = path.resolve(__dirname, '..');
const pkg = require('../package.json');
const stage = fs.mkdtempSync(path.join(os.tmpdir(), 'qwen-vsix-'));
try {
  const ext = path.join(stage, 'extension'); fs.mkdirSync(ext);
  for (const name of ['package.json', 'README.md', 'TEST-REPORT.md', 'LICENSE', 'dist']) fs.cpSync(path.join(root, name), path.join(ext, name), {recursive:true});
  fs.writeFileSync(path.join(stage, '[Content_Types].xml'), '<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="json" ContentType="application/json"/><Default Extension="js" ContentType="application/javascript"/><Default Extension="map" ContentType="application/json"/><Default Extension="md" ContentType="text/markdown"/><Default Extension="vsixmanifest" ContentType="text/xml"/><Default Extension="" ContentType="text/plain"/></Types>');
  fs.writeFileSync(path.join(stage, 'extension.vsixmanifest'), `<?xml version="1.0" encoding="utf-8"?><PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011"><Metadata><Identity Language="en-US" Id="${pkg.name}" Version="${pkg.version}" Publisher="${pkg.publisher}"/><DisplayName>${pkg.displayName}</DisplayName><Description xml:space="preserve">${pkg.description}</Description><Tags>qwen,cpp,ollama</Tags><Categories>Programming Languages</Categories><Properties><Property Id="Microsoft.VisualStudio.Code.Engine" Value="${pkg.engines.vscode}"/><Property Id="Microsoft.VisualStudio.Code.ExtensionKind" Value="workspace"/></Properties></Metadata><Installation><InstallationTarget Id="Microsoft.VisualStudio.Code"/></Installation><Dependencies/><Assets><Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true"/><Asset Type="Microsoft.VisualStudio.Services.Content.Details" Path="extension/README.md" Addressable="true"/></Assets></PackageManifest>`);
  const output = path.join(root, `${pkg.name}-${pkg.version}.vsix`); fs.rmSync(output, {force:true});
  cp.execFileSync('zip', ['-qr', output, '.'], {cwd:stage}); console.log(output);
} finally { fs.rmSync(stage, {recursive:true,force:true}); }
