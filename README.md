# Driver App - MVP

Este é o repositório do MVP "Driver App", um PWA construído com Flutter e Firebase.

## 1. Visão Geral

O projeto consiste em:
- **Flutter Web App (`/app`):** Um PWA para motoristas instalarem em seus celulares.
- **Cloud Functions (`/functions`):** Backend seguro para operações críticas e de administração.
- **Firebase Hosting:** Para publicar o PWA.
- **Firestore:** Banco de dados NoSQL com regras de segurança restritivas.

## 2. Setup do Ambiente

### Pré-requisitos
1.  **Node.js:** Instale a versão 18 ou superior.
2.  **Flutter:** [Instale o SDK do Flutter](https://docs.flutter.dev/get-started/install).
3.  **Firebase CLI:** Instale com `npm install -g firebase-tools`.

### Configuração do Firebase
1.  Faça login no Firebase: `firebase login`
2.  Configure seu projeto: `firebase use --add` e selecione seu projeto Firebase.
3.  Instale as dependências das Cloud Functions:
    ```bash
    cd functions
    npm install
    cd ..
    ```
4.  Instale as dependências do Flutter:
    ```bash
    cd app
    flutter pub get
    cd ..
    ```

## 3. Rodando com Emuladores

Para testar localmente, use os emuladores do Firebase. Eles simulam os serviços de Auth, Firestore e Functions na sua máquina.

1.  Inicie os emuladores:
    ```bash
    firebase emulators:start
    ```
2.  Em outro terminal, execute o aplicativo Flutter no modo de desenvolvimento:
    ```bash
    cd app
    flutter run -d chrome --web-port 8082
    ```
    > O app estará disponível em `http://localhost:8082`.
    > A UI dos emuladores estará em `http://localhost:4000`.

## 4. Bootstrap Seguro do Primeiro Admin

1. **Defina a BOOTSTRAP_KEY**
   - **Emuladores:** crie um arquivo `.env.local` na pasta `functions` com `BOOTSTRAP_KEY=...` e rode:
     ```bash
     cd functions
     echo "BOOTSTRAP_KEY=MINHA_CHAVE_FORTE" >> .env.local
     firebase emulators:start --only functions,firestore,auth
     ```
   - **Produção:** defina a variável de ambiente antes do deploy (ex.: em CI/CD) ou use secret:
     ```bash
     firebase functions:secrets:set BOOTSTRAP_KEY --data-file <(echo -n "MINHA_CHAVE_FORTE")
     firebase deploy --only functions
     ```
     > A Function lê `process.env.BOOTSTRAP_KEY`; garanta que a variável esteja presente no runtime (secret ou variável exportada) no momento do deploy.

2. **Chame a Callable `bootstrapAdmin` (uma única vez)**
   - Autentique-se com a conta que será o primeiro admin (crie conta via app ou Auth Emulator).
   - Execute via Flutter (exemplo temporário):
     ```dart
     import 'package:cloud_functions/cloud_functions.dart';

     Future<void> bootstrapAdmin(String key) async {
       final callable = FirebaseFunctions.instance.httpsCallable('bootstrapAdmin');
       await callable.call({'bootstrapKey': key});
     }
     ```
   - Ou via REST usando o token de auth do usuário autenticado:
     ```bash
     curl -X POST \
       "http://localhost:5001/$(firebase use --json | jq -r '.results.current')/us-central1/bootstrapAdmin" \
       -H "Content-Type: application/json" \
       -H "Authorization: Bearer $USER_TOKEN" \
       -d '{ "data": { "bootstrapKey": "MINHA_CHAVE_FORTE" } }'
     ```

3. **Desative o bootstrap após uso**
   - Remova ou limpe `BOOTSTRAP_KEY` do ambiente (apague do `.env.local`, variável de ambiente ou secret) após confirmar que o admin foi criado.

4. **Testes manuais recomendados**
   - Criar conta, chamar `bootstrapAdmin` com a chave correta e verificar no Firestore `users/{uid}.role == "admin"` e `status == "approved"`.
   - Repetir a chamada deve falhar com erro de precondition (bootstrap já usado).

5. **Script Node opcional (sem mexer no app Flutter)**
   ```bash
   export FIREBASE_API_KEY=...
   export FIREBASE_AUTH_DOMAIN=...
   export FIREBASE_PROJECT_ID=...
   export FIREBASE_APP_ID=...
   export ADMIN_EMAIL=...
   export ADMIN_PASSWORD=...
   export BOOTSTRAP_KEY=...
   # Para emulador (opcional): export FIREBASE_FUNCTIONS_EMULATOR_HOST=localhost:5001
   node scripts/bootstrap-admin.mjs
   ```

## 5. Fluxo de Teste (Convite e Cadastro)

1.  **Crie um Admin (usando bootstrapAdmin uma única vez):**
    -   Autentique um usuário e chame `bootstrapAdmin` com a chave definida.

2.  **Crie um Convite (usando a API de Admin):**
    -   Use a chamada `curl` abaixo para criar um convite para um futuro motorista.

3.  **Cadastre o Motorista:**
    -   Abra o PWA (`http://localhost:8082`).
    -   Crie uma nova conta usando o email exato para o qual o convite foi gerado.
    -   Após o login, o app pedirá o código do convite.
    -   Insira o código para ativar a conta do motorista.

## 6. Deploy

Para fazer o deploy do PWA e das Functions para o ambiente de produção do Firebase:

1.  **Construa o App Flutter:**
    ```bash
    cd app
    flutter build web
    cd ..
    ```
2.  **Faça o Deploy de Tudo:**
    ```bash
    firebase deploy
    ```

## 7. API para Admin (Exemplos com `curl`)

Estas são as chamadas que o painel admin (Lovable) pode fazer. 
**Importante:** É necessário obter um token de autenticação de um usuário admin do Firebase para incluir no cabeçalho `Authorization`.

### Exemplo de como obter o token:

```bash
# Faça login com o usuário admin e pegue o token
TOKEN=$(firebase login:ci --interactive | grep "\"token\"" | awk -F '\"' '{print $4}')
PROJECT_ID=$(gcloud config get-value project)

# Exporte as variáveis para usar nos comandos abaixo
export TOKEN
export PROJECT_ID
```

### a) Criar Convite

```bash
curl -X POST \
  https://us-central1-$PROJECT_ID.cloudfunctions.net/adminCreateInvite \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
        "data": {
            "target": "motorista@exemplo.com",
            "ttlDays": 15
        }
    }'
```

### b) Criar Corrida

```bash
curl -X POST \
  https://us-central1-$PROJECT_ID.cloudfunctions.net/adminCreateRide \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
        "data": {
            "pickup": { "address": "Rua A, 123", "lat": -23.55, "lng": -46.63 },
            "dropoff": { "address": "Rua B, 456", "lat": -23.56, "lng": -46.64 },
            "datetime": "2024-08-15T10:00:00Z",
            "price": 50.75,
            "passengerName": "João Silva",
            "passengerPhone": "11987654321",
            "notes": "Levar mala grande"
        }
    }'
```

### c) Atribuir Corrida

```bash
curl -X POST \
  https://us-central1-$PROJECT_ID.cloudfunctions.net/adminAssignRide \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
        "data": {
            "rideId": "ID_DA_CORRIDA_GERADO_ACIMA",
            "driverId": "UID_DO_MOTORISTA_APROVADO"
        }
    }'
```
