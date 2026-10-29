# Easy Eats · Guia d’ús per a Windows

## Accés d’administrador

| Usuari | Contrasenya |
| --- | --- |
| `operario` | `demo1234` |

## 1. Obrir l’app

Requisits: Windows 10 o 11 de 64 bits i connexió a Internet.

Descomprimiu Easy_Eats_Windows.zip. Obriu la carpeta Easy_Eats i feu doble clic a easyeats.exe.

Conserveu els fitxers DLL i la carpeta data al costat de l’executable. Cal extreure tot el ZIP; no executeu el programa des de dins de l’arxiu comprimit.

L’app utilitza el servei remot del projecte. No cal instal·lar Python, Flutter ni iniciar cap servidor al vostre ordinador.

## 2. Crear un client

A la pantalla inicial, trieu Crear cuenta, escolliu un usuari i una contrasenya i conserveu-los per tornar a entrar.

Completeu el perfil: pla Free o Pro, dies i àpats, dieta, al·lèrgens declarats, ingredients exclosos i gustos. Cal marcar almenys un àpat setmanal. Pro afegeix la vista d’entregues i el camp de direcció.

Premeu Guardar y continuar. Per avaluar-la, utilitzeu dades fictícies. Les fitxes dels plats no certifiquen l’absència real d’al·lèrgens.

## 3. Generar i consultar el menú

Obriu Semana. Les fletxes permeten consultar altres setmanes. Si el mes no té menú, premeu Generar menú de AAAA-MM.

La primera proposta del compte queda pendent de revisió de l’administrador. Després de l’aprovació, torneu al mateix client per veure els plats publicats.

Detalle mostra ingredients i al·lèrgens registrats. Catálogo permet explorar els plats. A Perfil podeu consultar i modificar les preferències.

Cambiar permet escollir un altre plat d’una data futura. El canvi es desa directament, sense repetir l’aprovació. Opinar permet valorar plats d’avui o anteriors.

## 4. Entrar com a administrador

El rol d’administrador apareix a l’app com a Operario. Utilitza la mateixa pantalla d’accés que el client.

Si teniu una sessió de client oberta, premeu Cerrar sesión. Introduïu operario i demo1234 i premeu Entrar.

Al panell Easy Eats · Operario, obriu una proposta pendent i reviseu el perfil, les dates i els plats. Podeu utilitzar Sustituir o Regenerar mes abans d’aprovar.

Premeu Aprobar primer menú. La proposta desapareixerà de pendents. Tanqueu la sessió i torneu al client per comprovar el menú publicat.

Si la cua és buida, creeu primer un client i genereu-ne el primer menú. Els mesos següents d’un client ja revisat es publiquen sense repetir la revisió inicial.

## 5. Recorregut d’avaluació

Crear client i desar perfil → generar primer menú → entrar com a operari → revisar i aprovar → tornar al client → obrir Detalle i canviar un plat futur.

Anoteu les credencials del client abans de canviar de rol. El compte operario serveix per revisar, no per crear un menú personal.

## 6. Si apareix un problema

L’app no s’obre: comproveu que heu extret tota la carpeta i que data i flutter_windows.dll són al costat de l’executable.

Falta MSVCP140 o VCRUNTIME140: instal·leu Microsoft Visual C++ Redistributable x64 des de l’enllaç oficial indicat a continuació i torneu a obrir l’app.

No connecta amb el servei: comproveu Internet. Si continua fallant, contacteu amb l’equip perquè comprovi el servei remot.

No apareix Cambiar: aneu a una data futura amb un menú aprovat. Credencials incorrectes: comproveu el compte de client o utilitzeu el compte d’operari facilitat.

Microsoft Visual C++ x64: https://aka.ms/vc14/vc_redist.x64.exe

Informació oficial: https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist/
