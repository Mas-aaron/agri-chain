$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent

function Replace-InFile {
  param([string]$Path,[hashtable]$Map)
  if (!(Test-Path $Path)) { return }
  $c = Get-Content -Path $Path -Raw -Encoding UTF8
  foreach ($k in $Map.Keys) { $c = $c.Replace($k, $Map[$k]) }
  Set-Content -Path $Path -Value $c -Encoding UTF8
}

# Replace package prefix across all dart files
$map = @{
  'package:maize_disease_detector/' = 'package:agri_chain/'
}
Get-ChildItem -Path (Join-Path $root 'lib') -Recurse -Filter *.dart | ForEach-Object {
  $c = Get-Content -Path $_.FullName -Raw -Encoding UTF8
  $new = $c.Replace('package:maize_disease_detector/','package:agri_chain/')
  if ($new -ne $c) { Set-Content -Path $_.FullName -Value $new -Encoding UTF8 }
}

# Ensure home_screen.dart has File and ImagePicker imports
$homePath = Join-Path $root 'lib\home_screen.dart'
if (Test-Path $homePath) {
  $c = Get-Content -Path $homePath -Raw -Encoding UTF8
  if ($c -notmatch "import 'dart:io';") {
    $c = $c -replace "import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';`r`nimport 'dart:io';"
  }
  if ($c -notmatch 'image_picker') {
    $c = $c -replace "import 'package:provider/provider.dart';", "import 'package:provider/provider.dart';`r`nimport 'package:image_picker/image_picker.dart';"
  }
  Set-Content -Path $homePath -Value $c -Encoding UTF8
}

Write-Host 'Import fixes applied.'
