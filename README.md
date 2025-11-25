# LeakGuard MQ-2

Monitoramento de gás com ESP32 + MQ-2 -> Firebase -> app console Dart (SDK 3.9.2) -> MySQL -> Power BI. Polling a cada 3s mantém leituras praticamente em tempo real.

## Fluxo do sistema
1) ESP32 publica estado (ativo/detectado) e nível (ppm) no Firebase Realtime Database.
2) Console Dart carrega .env, autentica anonimamente no Firebase e prepara MySQL.
3) Snapshot inicial lê o sensor e sincroniza `dispositivo.ativo`.
4) Polling (3s) repete leitura e aplica regras:
   - grava variação de nível em `leituragas`;
   - gera alertas: moderado (>25 ppm) ou crítico (>30 ppm) em `alerta`;
   - mantém `dispositivo` e `historicouso` atualizados.
5) Menu interativo: `menu` abre; login via .env; listagens para usuário comum; criação de localização/dispositivo para admin; `sair` encerra.
6) Power BI consome o MySQL para dashboards.

## Estrutura do projeto
- `bin/main.dart`: orquestração. Carrega .env, autentica no Firebase, cria services/DAOs, semeia localização/usuários, roda snapshot inicial, inicia polling e input do usuário.
- `lib/controllers/`
  - `sensor_controller.dart`: coordena snapshot e polling, garante dispositivo, grava leituras, dispara alertas.
  - `input_controller.dart`: comandos globais `menu`/`sair` e roteamento para a view.
- `lib/views/console_view.dart`: menu não bloqueante (login simples, listagens, criação admin).
- `lib/services/` (regras leves + orquestração de DAOs)
  - `auth_service.dart`: login anônimo Firebase.
  - `firebase_service.dart`: GET único e polling 3s do Realtime Database.
  - `db_service.dart`: abre conexões MySQL.
  - `leitura_service.dart`: converte Firebase -> `leituragas`.
  - `alerta_service.dart`: classifica nível e grava `alerta`.
  - `dispositivo_service.dart`: seed e sync `dispositivo`.
  - `localizacao_service.dart`: seed e CRUD básico de `localizacao`.
  - `usuario_service.dart`: seed usuários de `.env`.
  - `historico_uso_service.dart`: registra ações de admin.
- `lib/daos/`: acesso direto ao MySQL para `dispositivo`, `localizacao`, `leituragas`, `alerta`, `usuario`, `historicouso` e consultas de menu.
- `lib/models/`: modelos simples para entidades e para `FirebaseLeitura`.

## Como usar
1) Pré-requisitos: Dart SDK 3.9.2, MySQL ativo (banco criado), Firebase Realtime Database configurado.
2) Configure `.env` com base do Firebase, API key, credenciais MySQL, logins admin/usuário.
3) Crie o banco de dados MySQL com o seguinte script: https://justpaste.it/lvziw
4) Instale dependências: `dart pub get`.
5) Rode: `dart run bin/main.dart`.
6) Em execução: acompanhe logs; `menu` para listar/criar; `sair` para encerrar.

## Bibliotecas (pubspec)
- http (REST Firebase)
- mysql1 (MySQL)
- intl (formatação data/número)
- dotenv (variáveis .env)

## Tecnologias
- ESP32 + Sensor MQ-2  
- Firebase Realtime Database  
- Dart (console app)  
- MySQL  
- Power BI  

LINK DO POWERBI SERVICE COM MODELO DO DASHBOARD: https://bit.ly/leakguardbi
Autores: [Cauã Micael Rosato, Eduardo Baldo, Matheus Gabriel De Melo Tesch, Thiago Mafra Domingues]
