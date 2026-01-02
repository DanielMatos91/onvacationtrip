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

## 4. Fluxo de Teste (Convite e Cadastro)

1.  **Crie um Admin (Manual):**
    -   Acesse a UI do Emulador de Autenticação (`http://localhost:4000/auth`).
    -   Crie um usuário (ex: `admin@test.com`).
    -   Vá para a UI do Emulador do Firestore (`http://localhost:4000/firestore`).
    -   Na coleção `users`, edite o documento do admin recém-criado e adicione o campo `role` com o valor `"admin"`.

2.  **Crie um Convite (usando a API de Admin):
    -   Use a chamada `curl` abaixo para criar um convite para um futuro motorista.

3.  **Cadastre o Motorista:**
    -   Abra o PWA (`http://localhost:8082`).
    -   Crie uma nova conta usando o email exato para o qual o convite foi gerado.
    -   Após o login, o app pedirá o código do convite.
    -   Insira o código para ativar a conta do motorista.

## 5. Deploy

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

## 6. API para Admin (Exemplos com `curl`)

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
