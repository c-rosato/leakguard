# LeakGuard MQ-2

Sistema de monitoramento de gás utilizando **ESP32**, **sensor MQ-2**, **Firebase**, **Dart (console)** e **MySQL**, com visualização no **Power BI**.

##  Fluxo do sistema

ESP32 (MQ-2) → Firebase → Dart Console → MySQL → Power BI

##  Funcionalidade

- O **ESP32** envia leituras do sensor MQ-2 para o **Firebase Realtime Database**.
- O **Dart Console** recebe e exibe as leituras em tempo real.
- Os dados são gravados no **MySQL**, incluindo:
  - Leituras de gás (`leitura_gas`)
  - Status dos dispositivos (`dispositivo`)
  - Alertas automáticos (`alerta`)
  - Histórico de uso e ações (`historico_uso`)
- O **Power BI** consome o banco de dados para gerar dashboards.

##  Tecnologias

- ESP32 + Sensor MQ-2  
- Firebase Realtime Database  
- Dart (console app)  
- MySQL  
- Power BI  

 Autores: [Cauã Micael Rosato, Eduardo Baldo, Matheus Eduardo Chiodeto, Matheus Gabriel De Melo Tesch, Thiago Mafra Domingues]