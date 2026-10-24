# Accés al prototip Easy Eats

Aquest paquet conté la web compilada, l'API FastAPI i el catàleg SQLite de demostració. Permet recórrer el registre d'un client, la configuració del perfil, la generació del menú mensual, l'aprovació inicial per part de l'operari, la consulta setmanal i el canvi de plats futurs.

## Requisits

- Windows amb Python 3.12 o posterior i connexió per instal·lar les dependències de `backend/requirements.txt`.
- Dos terminals PowerShell. Per provar-lo des d'un altre dispositiu, els dos equips han de ser a la mateixa xarxa local.

## Inici al mateix ordinador

Des de la carpeta extreta del ZIP, al primer terminal:

```powershell
cd backend
py -3 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
$env:EASY_EATS_GENERATION_MODE = 'test'
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Al segon terminal, des de la carpeta extreta del ZIP:

```powershell
cd web
..\backend\.venv\Scripts\python.exe -m http.server 8080 --bind 0.0.0.0
```

Obriu `http://localhost:8080`. L'API respon a `http://localhost:8000/system/capabilities`. Per provar-lo des d'un altre equip, obriu `http://IP_DEL_SERVIDOR:8080` i, a **Servidor LAN** de la pantalla d'accés, poseu `http://IP_DEL_SERVIDOR:8000`. Si el tallafoc ho demana, permeteu els ports 8000 i 8080 a la xarxa privada. Canvieu `EASY_EATS_OPERATOR_PASSWORD` abans d'obrir el servidor en una LAN compartida.

## Recorregut de la demostració

1. Trieu **Crear cuenta** i creeu un usuari de prova. Configureu el pla Free, dies i àpats diferents, i una dieta. Deseu el perfil.
2. A **Semana**, genereu el menú del mes. La primera proposta queda pendent de revisió.
3. Tanqueu la sessió i entreu com a `operario`. La contrasenya inicial és `demo1234`, tret que s'hagi definit `EASY_EATS_OPERATOR_PASSWORD` al servidor. Obriu la proposta i premeu **Aprobar primer menú**.
4. Torneu al client. Consulteu la setmana i avanceu a una amb plats futurs per provar **Cambiar**. El catàleg permet veure el detall dels plats. Es pot registrar una opinió sobre plats del dia actual o anteriors.

Les dades de comptes i menús es creen a `backend/var/app_test.sqlite` al primer inici. El catàleg alimentari és fictici i els seus al·lèrgens no estan verificats per a consum real. Utilitzeu credencials i adreces de prova.

## Ús de la IA

La configuració inclosa és **mode de proves**: el menú el genera un algorisme local determinista, sense IA. El codi incorpora un adaptador per a Groq, provat amb una resposta simulada. Per afirmar que la funció d'IA real funciona, cal configurar una clau al servidor, activar `EASY_EATS_GENERATION_MODE=ai` i verificar una generació mensual completa. No s'inclou cap clau en aquest paquet.

La fitxa inicial feta a mà no s'ha reescrit ni inclòs com a nou lliurable. Les dues proves amb persones externes i la millora basada en les observacions continuen pendents.
