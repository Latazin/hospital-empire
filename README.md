# 🏥 Hospital Empire — Idle Tycoon (Flutter + Flame)

Jogo idle tycoon de hospital em visão isométrica 2.5D cartoon. O hospital inteiro é um mundo renderizado pelo **Flame**: pacientes chegam pela calçada, fazem check-in na recepção, são atendidos nas salas, pagam e vão embora; carregadores levam o dinheiro até a tesouraria; ambulâncias trazem emergências; inspetores avaliam o hospital.

## Como gerar o APK sem computador (GitHub Actions)

1. Crie um repositório no GitHub (pode ser privado) e envie todo o conteúdo desta pasta.
2. O GitHub roda o workflow `.github/workflows/build.yml` automaticamente a cada envio.
3. Abra a aba **Actions → Build Android → (última execução) → Artifacts** e baixe `hospital-empire-apk` (para instalar) e `hospital-empire-aab` (para a Play Store).

## Como rodar no computador

Requisitos: Flutter 3.22+ (stable) e Android SDK.

```bash
bash setup.sh          # Windows: setup.bat  (cria a pasta android/, ícone e splash)
flutter run            # roda no celular/emulador
flutter build apk --release
flutter build appbundle --release
```

## Publicação na Google Play

O AAB gerado acima é assinado com a chave de debug. Para publicar:

1. Gere a chave: `keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
2. Crie `android/key.properties` com `storePassword`, `keyPassword`, `keyAlias=upload` e `storeFile=../upload-keystore.jks`.
3. No `android/app/build.gradle(.kts)`, configure `signingConfigs.release` lendo esse arquivo e use-o no `buildTypes.release` (guia oficial: docs.flutter.dev/deployment/android).
4. Arte pronta: `assets/images/icon.png` (512px a partir dele) e `assets/images/feature_graphic.png` (1024×500).

Permissões: nenhuma além das padrão (sem internet, sem localização). Vibração usa o feedback háptico do sistema.

## Estrutura

```
lib/
  core/      economia, estado, progressão, save, áudio
  game/      mundo Flame: câmera, salas, personagens, eventos
  ui/        HUD sobreposto e painéis
assets/      sons, música, ícone, splash (gerados por tool/gen_assets.py)
test/        testes da economia e do salvamento
```

## Sistemas

- **Mundo**: arrastar, pinça para zoom, botões de zoom, toque nas salas/recepção/tesouraria.
- **Loop**: chegada → fila → check-in → sala → atendimento → pagamento → carregador → tesouraria → COLETAR.
- **8 salas**: Consultório, Laboratório, Farmácia, Enfermaria (por reputação); Radiologia, Centro Cirúrgico, UTI, Maternidade (por unidade). Até nível 100, vagas extras nos níveis 10/20/30, renda x2 nos níveis 25/50/75/100, visual evolui em 4 estágios.
- **Infraestrutura**: Recepção (check-in, fila), Transporte (até 5 carregadores, capacidade, velocidade), Tesouraria (limite, coleta automática com gerente).
- **Gerentes**: 11 normais + 4 exclusivos, níveis 1–10, pagos com ouro.
- **Eventos**: emergências (ambulância), VIPs, epidemias, inspeções com nota A–D, Plantão Relâmpago (x3), evento semanal rotativo com desafio e gerente exclusivo.
- **Meta**: ouro, reputação, missões diárias, objetivos sequenciais, 16 conquistas, 12 colecionáveis em 3 coleções, estatísticas, expansão para novas unidades (prestígio com multiplicador permanente), ganhos offline até 8h.
- **Qualidade**: tutorial, salvamento automático a cada 15s e ao sair (com cópia de segurança), música, efeitos, vibração.

## Observações técnicas

- Gráficos e animações são desenhados por código (canvas) no Flame, com cache em `Picture` para rodar bem em aparelhos intermediários. Para trocar por sprites desenhados à mão, substitua o `render` de `Person`/`RoomComponent` por `SpriteAnimationComponent`.
- O progresso é salvo em JSON via SharedPreferences (com backup alternado). Para migrar para SQLite, troque apenas `lib/core/save_service.dart`.
- Fórmulas de balanceamento ficam todas em `lib/core/economy.dart`.
