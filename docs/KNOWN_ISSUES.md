# Scanner QR

## Sintoma

No modo Debug funciona normalmente.

No APK Release aparece:

"Não foi possível abrir a câmera."

## Causa

R8 remove classes do ML Kit durante a geração do APK.

## Solução

Adicionar:

-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

no arquivo

android/app/proguard-rules.pro