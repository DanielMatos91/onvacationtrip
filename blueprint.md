# Driver App - MVP Blueprint

## 1. Visão Geral

Este documento descreve o plano de desenvolvimento para o MVP do "Driver App", um Progressive Web App (PWA) construído com Flutter e Firebase. O objetivo é criar uma plataforma onde administradores possam gerenciar convites e corridas, e motoristas possam visualizar e interagir com as corridas atribuídas a eles.

## 2. Estrutura do Projeto

O projeto foi organizado da seguinte forma:

```
/
|-- app/                # Aplicação Flutter (PWA)
|   |-- lib/
|   |   |-- main.dart
|   |   |-- models/
|   |   |-- screens/
|   |   |-- services/
|   |-- pubspec.yaml
|   |-- web/              # Configurações PWA (manifest.json, icons)
|
|-- functions/          # Cloud Functions (TypeScript)
|   |-- src/
|   |   |-- index.ts
|   |-- package.json
|
|-- firebase.json       # Configuração do Firebase (emulators, hosting)
|-- firestore.rules     # Regras de Segurança do Firestore
|-- firestore.indexes.json # Índices do Firestore
|-- README.md           # Documentação do projeto
|-- blueprint.md        # Este arquivo
```

## 3. Plano de Implementação Concluído

### Fase 1: Configuração do Backend e Estrutura (Concluída)

1.  **Limpeza do Projeto:** A estrutura de app Flutter inicial foi removida da raiz.
2.  **Criação da Estrutura:**
    -   Um novo projeto Flutter foi criado no diretório `/app`.
    -   O `firebase.json` foi configurado para os emuladores (Auth, Firestore, Functions) e para o Hosting, apontando para o build do PWA (`app/build/web`).
3.  **Modelagem de Dados e Regras:**
    -   As regras de segurança foram implementadas no `firestore.rules`, garantindo acesso restrito aos dados.
    -   O arquivo `firestore.indexes.json` foi criado para otimizar as queries necessárias.
4.  **Cloud Functions (Core):**
    -   Todas as Cloud Functions especificadas foram implementadas em `functions/src/index.ts` com validação de autenticação (admin/driver) e lógica de negócio:
        -   `adminCreateInvite`
        -   `redeemInvite`
        -   `adminCreateRide`
        -   `adminAssignRide`
        -   `driverUpdateRideStatus`

### Fase 2: Desenvolvimento do Flutter PWA (Concluída)

1.  **Dependências:** As dependências `firebase_core`, `firebase_auth`, `cloud_firestore`, `cloud_functions`, `provider`, `go_router`, e `geolocator` foram adicionadas ao `app/pubspec.yaml`.
2.  **Configuração Inicial:**
    -   O Firebase foi inicializado em `app/lib/main.dart` usando `DefaultFirebaseOptions.currentPlatform`.
    -   O `GoRouter` foi configurado para gerenciar a navegação, com um `AuthGate` para controlar o acesso com base no status de autenticação e do usuário.
    -   O `ChangeNotifierProvider` foi utilizado para o `AuthService`, permitindo o gerenciamento de estado reativo.
3.  **Serviços de Backend:**
    -   A camada de serviço em `app/lib/services/` foi criada, encapsulando a lógica de negócio:
        -   `AuthService`: Gerencia a autenticação de usuários, o resgate de convites e o estado do usuário.
        -   `LocationService`: Gerencia o rastreamento da localização do motorista em tempo real.
4.  **Telas (Screens):**
    -   **Autenticação:** Foi criado um fluxo de navegação robusto que direciona o usuário para:
        -   `LoginScreen` / `SignUpScreen`: Para entrada e criação de contas.
        -   `InviteScreen`: Para usuários que precisam resgatar um convite após o login.
        -   `PendingScreen`: Para motoristas aguardando aprovação de um administrador.
    -   **Corridas:**
        -   `RidesListScreen`: Exibe uma lista em tempo real das corridas atribuídas ao motorista.
        -   `RideDetailScreen`: Mostra detalhes da corrida e permite a atualização do status.
    -   **Suporte:** Uma tela `SupportScreen` foi implementada para que os motoristas possam enviar tickets de suporte.
5.  **Funcionalidades Adicionais:**
    -   A atualização de localização em tempo real foi implementada no `LocationService` e integrada ao `AuthGate` para iniciar e parar o rastreamento automaticamente.
    -   A configuração do PWA em `app/web/` foi deixada como padrão, pronta para customização.

### Fase 3: Documentação e Finalização (Concluída)

1.  **README.md:** Um `README.md` detalhado foi criado, incluindo:
    -   Instruções de setup do ambiente (Firebase CLI, Flutter).
    -   Comandos para rodar os emuladores.
    -   Comandos para fazer o deploy do projeto.
    -   Um guia passo a passo do fluxo de convite e gerenciamento de corridas.
2.  **Documentação de API (Lovable):**
    -   O `README.md` inclui exemplos de chamadas `curl` para as funções de admin, facilitando testes e integrações.

