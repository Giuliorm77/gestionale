const fs=require("fs");
const NODE=1;
const Babel=require("C:/Users/utente/OneDrive/Desktop/Gestionale2026/lib/babel.min.js");
const html=fs.readFileSync("C:/Users/utente/OneDrive/Desktop/Gestionale2026/index.html","utf8");
// estrai tutti i blocchi <script type="text/babel">
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
