// Verifica compilazione dei blocchi <script type="text/babel"> di Komunigo/index.html
// Uso: & "C:\Program Files\nodejs\node.exe" compilecheck.js
const fs=require("fs");
const Babel=require("C:/Users/utente/OneDrive/Desktop/Gestionale2026/Komunigo/lib/babel.min.js");
const html=fs.readFileSync("C:/Users/utente/OneDrive/Desktop/Gestionale2026/Komunigo/index.html","utf8");
const re=/<script[^>]*type=["']text\/babel["'][^>]*>([\s\S]*?)<\/script>/gi;
let m, n=0, totErr=0;
while((m=re.exec(html))){
  n++;
  const code=m[1];
  try{
    Babel.registerPreset && Babel.availablePresets && Babel.availablePresets.react &&
      Babel.registerPreset('react-classic',{presets:[[Babel.availablePresets.react,{runtime:'classic'}]]});
    Babel.transform(code,{presets:['react-classic']});
    console.log(`blocco #${n}: OK (${code.length} char)`);
  }catch(e){
    totErr++;
    console.log(`blocco #${n}: ERRORE -> ${e.message}`);
  }
}
console.log(`\nBlocchi babel trovati: ${n}, con errori: ${totErr}`);
