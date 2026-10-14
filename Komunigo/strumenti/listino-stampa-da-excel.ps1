# =====================================================================
#  Listino di acquisto stampa: dal file Excel compilato allo script SQL.
#  Legge "Listino-Stampa-Acquisto-DA-COMPILARE.xlsx" (fogli Serigrafia /
#  Ricamo abbigliamento) e scrive un .sql che:
#   - salva la griglia in prodotti_config.listino_stampa del modello
#     "Stampa abbigliamento (modello)" (chiavi "serigrafia" / "ricamo");
#   - aggiorna area massima e colori massimi delle 8 posizioni.
#  Uso:  powershell -File listino-stampa-da-excel.ps1 -Excel <file.xlsx> -Sql <out.sql>
#  Poi: Supabase -> SQL Editor -> incolla il .sql -> Run.
# =====================================================================
param(
  [Parameter(Mandatory=$true)][string]$Excel,
  [Parameter(Mandatory=$true)][string]$Sql
)
$ErrorActionPreference = "Stop"
$inv = [System.Globalization.CultureInfo]::InvariantCulture
function Num($v){ if ($null -eq $v -or "$v".Trim() -eq "") { return $null }; if ($v -is [double]) { return [double]$v }
  $t = "$v".Replace("€","").Replace(" ","").Trim(); if ($t -match ",") { $t = $t.Replace(".","").Replace(",",".") }
  $d = 0.0; if ([double]::TryParse($t, [System.Globalization.NumberStyles]::Float, $inv, [ref]$d)) { return $d }; return $null }
function Q($s){ "'" + ("$s" -replace "'","''") + "'" }

$x = New-Object -ComObject Excel.Application; $x.DisplayAlerts = $false
try {
  $wb = $x.Workbooks.Open($Excel, 0, $true)
  $out = New-Object System.Collections.Generic.List[string]
  $out.Add("-- Listino di acquisto stampa generato da: " + (Split-Path $Excel -Leaf) + " il " + (Get-Date -Format "yyyy-MM-dd HH:mm"))
  $out.Add("-- Supabase -> SQL Editor -> Run. Sicuro da rieseguire.")
  $tecniche = @()

  # ---------- SERIGRAFIA ----------
  $s = $wb.Worksheets.Item("Serigrafia abbigliamento")
  $imp = Num $s.Range("B3").Value2
  $righe = @()
  for ($r = 7; $r -le 14; $r++) {
    $da = Num $s.Cells.Item($r,1).Value2; if ($null -eq $da) { continue }
    $pz = @()
    for ($c = 1; $c -le 4; $c++) { $v = Num $s.Cells.Item($r, $c+1).Value2; if ($null -ne $v -and $v -gt 0) { $pz += ('"' + $c + '": ' + $v.ToString($inv)) } }
    if ($pz.Count) { $righe += ('{"da": ' + ([int]$da) + ', "prezzi": {' + ($pz -join ", ") + '}}') }
  }
  if ($righe.Count) {
    $tecniche += ('"serigrafia": {"impianto_per_colore": ' + ([double]($(if ($imp) {$imp} else {0}))).ToString($inv) + ', "righe": [' + ($righe -join ", ") + ']}')
    $out.Add("-- serigrafia: " + $righe.Count + " scaglioni, impianto " + $imp + " EUR per colore")
  }
  $pos = @()
  for ($r = 22; $r -le 29; $r++) {
    $nome = "$($s.Cells.Item($r,1).Value2)".Trim(); if (-not $nome) { continue }
    $area = "$($s.Cells.Item($r,2).Value2)".Trim(); $maxc = Num $s.Cells.Item($r,3).Value2
    # area in mm nella tabella → cm nel negozio (es. "80 x 80" → "8 × 8")
    $itc = [System.Globalization.CultureInfo]::GetCultureInfo("it-IT")
    $cm = (($area -split "\s*[xX×]\s*") | ForEach-Object { $n = Num $_; if ($null -ne $n) { ([math]::Round($n/10,1)).ToString($itc) } }) -join " × "
    $set = @(); if ($cm) { $set += "area_cm = " + (Q $cm) }
    if ($maxc) { $set += "max_colori = " + [int]$maxc }
    if ($set.Count) { $pos += "update public.prodotti_config_stampe set " + ($set -join ", ") + " where prodotto_id = (select id from m) and nome = " + (Q $nome) + ";" }
  }

  # ---------- RICAMO ----------
  $r2 = $wb.Worksheets.Item("Ricamo abbigliamento")
  $punc = Num $r2.Range("B4").Value2
  $fasce = @(); for ($c = 2; $c -le 5; $c++) { $fasce += "$($r2.Cells.Item(7,$c).Value2)".Trim() }
  $righeR = @()
  for ($r = 8; $r -le 15; $r++) {
    $da = Num $r2.Cells.Item($r,1).Value2; if ($null -eq $da) { continue }
    $pz = @()
    for ($c = 1; $c -le 4; $c++) { $v = Num $r2.Cells.Item($r, $c+1).Value2; if ($null -ne $v -and $v -gt 0) { $pz += ('"' + $c + '": ' + $v.ToString($inv)) } }
    if ($pz.Count) { $righeR += ('{"da": ' + ([int]$da) + ', "prezzi": {' + ($pz -join ", ") + '}}') }
  }
  if ($righeR.Count) {
    $fj = ($fasce | ForEach-Object { '"' + ($_ -replace '"','') + '"' }) -join ", "
    $tecniche += ('"ricamo": {"impianto_per_colore": 0, "punciatura": ' + ([double]($(if ($punc) {$punc} else {0}))).ToString($inv) + ', "fasce": [' + $fj + '], "righe": [' + ($righeR -join ", ") + ']}')
    $out.Add("-- ricamo: " + $righeR.Count + " scaglioni (colonne = fasce di punti) - DA COLLEGARE nel configuratore (scelta fascia punti)")
  }
  $wb.Close($false)

  $out.Add("")
  $out.Add("with m as (select modello_stampa_id as id from public.catalogo_fornitore_sync where fornitore = 'newwave')")
  $out.Add("update public.prodotti_config set listino_stampa = '{" + ($tecniche -join ", ") + "}'::jsonb where id = (select id from m);")
  $out.Add("")
  foreach ($p in $pos) { $out.Add("with m as (select modello_stampa_id as id from public.catalogo_fornitore_sync where fornitore = 'newwave') " + $p) }
  $out.Add("")
  $out.Add("-- controllo")
  $out.Add("select nome, jsonb_pretty(listino_stampa) from public.prodotti_config where id = (select modello_stampa_id from public.catalogo_fornitore_sync where fornitore = 'newwave');")
  [System.IO.File]::WriteAllLines($Sql, $out, (New-Object System.Text.UTF8Encoding($false)))
  "SQL scritto: $Sql"
} finally { $x.Quit(); [System.Runtime.InteropServices.Marshal]::ReleaseComObject($x) | Out-Null }
