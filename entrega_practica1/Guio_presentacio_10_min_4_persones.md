# Guió oral d'Easy Eats — 10 minuts, 4 persones

**Llengua:** català. **Suport:** les dues diapositives de `Soporte_demo_Easy_Eats.pptx` i la web del prototip. **Durada prevista:** 9:30–10:00, incloent-hi els clics i les pauses de la demostració. Substituïu «Persona 1–4» pels noms del grup.

## Abans de començar

- Obrir la presentació a la diapositiva 1 i tenir la web i l'API en marxa en mode de proves.
- Preparar un client de demostració amb el perfil desat i la primera proposta pendent. Tenir a mà l'accés de l'operari. Si voleu ensenyar un canvi de plat sense esperar, preparar també un client amb un menú ja aprovat.
- Comprovar que el mes de prova inclou plats en una data futura, perquè el botó «Cambiar» només apareix per a plats futurs.
- Assajar els canvis de compte. Els textos entre claudàtors són accions i no s'han de llegir en veu alta.

## Diapositiva 1 — problema i recorregut

### Persona 1 · 0:00–2:15 · Origen i proposta

«Bon dia. Som el grup d'Easy Eats. El problema que vam triar és molt quotidià: decidir què menjar al llarg del mes sembla senzill, però es complica quan cada persona té dies disponibles, àpats diferents, gustos i restriccions alimentàries. Si algú ha de recollir tota aquesta informació a mà i repetir les mateixes preguntes per a cada client, el procés acaba sent lent i és fàcil perdre algun detall.

En la fitxa inicial, feta en paper, vam partir precisament d'aquesta relació entre el client i el treballador. Vam anotar idees relacionades amb automatitzar les preguntes, orientar la tria d'aliments i filtrar els plats segons les preferències. La idea que vam continuar desenvolupant combina aquests elements en un servei de menús personalitzats.

Easy Eats demana al client les decisions que realment afecten el menú: quins dies el necessita, quins àpats vol en cada dia i quines restriccions o preferències té. A partir d'això crea una proposta mensual i la presenta per setmanes. Això és important perquè el resultat no és només una llista de receptes: cada plat correspon a una data i a un àpat que la persona havia triat.

Per mantenir l'abast realista, el prototip no calcula calories ni fa recomanacions mèdiques. El nostre catàleg és de demostració i no té dades nutricionals verificades. Per això hem centrat la prova en un recorregut que sí que podem mostrar: configurar el perfil, generar el menú, revisar la primera proposta i deixar que el client consulti i canviï plats futurs. Ara veurem aquest recorregut a la web.»

**Traspàs:** «[Nom de la persona 2], ens ensenyes què decideix el client?»

### Persona 2 · 2:15–4:40 · Configuració i generació

[Mostrar la web amb el client de demostració. Obrir el perfil; assenyalar el calendari, la dieta i el pla.]

«Sí. Comencem amb un usuari de prova. Aquí el client pot triar el pla Free, que dona accés als menús. El pla Pro afegeix una vista d'entrega a domicili, però en aquest prototip l'entrega és simulada: no hi ha pagament ni repartiment real.

La part central del perfil és el calendari. No hem suposat que tothom vulgui esmorzar, dinar i sopar cada dia. Es pot escollir, per exemple, dinar dilluns, sopar dimecres i dos àpats divendres. Així el sistema només crea els espais que aquella persona ha demanat. Si no es marca cap àpat, l'aplicació demana que se'n triï almenys un abans de generar.

Després s'indica la dieta i, si cal, els ingredients o al·lèrgens declarats que s'han d'evitar. També hi ha gustos personals. Hem separat les restriccions de les preferències: una al·lèrgia és una condició que s'ha de respectar, mentre que dir “no m'agrada gaire un ingredient” serveix per prioritzar altres plats. Aquesta diferència importa perquè el sistema no ha de tractar un gust com si fos una prohibició mèdica, ni al revés.

[Obrir «Semana» i generar la proposta mensual del client pendent; si ja està generada, mostrar-ne l'estat pendent. Fer una pausa curta perquè es vegi el missatge.]

Ara demanem el menú del mes. El servidor crea un espai per a cada data i àpat seleccionats i busca plats compatibles al catàleg. La primera proposta d'aquest client queda pendent de revisió. El client veu aquest estat i no confon una proposta encara no aprovada amb el menú definitiu. Aquest control inicial ens permet incorporar una comprovació humana abans de publicar el primer resultat.»

**Traspàs:** «Qui fa aquesta revisió i què pot fer després el client?»

### Persona 3 · 4:40–7:15 · Revisió i ús del menú

[Entrar com a operari, obrir la proposta pendent i mostrar-ne les opcions. Aprovar-la. Tornar al client, o utilitzar el client aprovat que s'ha preparat abans.]

«La fa l'operari. Té una pantalla amb les primeres propostes pendents. Pot mirar la planificació mensual i les restriccions declarades pel client. Si detecta un plat inadequat per al cas de prova, pot substituir-lo; també pot demanar una altra proposta. Quan la revisió és correcta, aprova aquest primer menú. La revisió s'aplica a la primera proposta de cada client, i no a cada petit canvi que faci més endavant.

Tornem ara a la vista del client. El menú es consulta per setmanes. A cada targeta hi ha el dia, l'àpat i el plat assignat. Si obrim el detall, podem veure els ingredients i els al·lèrgens que el catàleg té registrats. Vull remarcar que aquestes fitxes són dades fictícies de prova: no certifiquen que un aliment real sigui segur per a una persona amb al·lèrgies.

[Avançar a una setmana amb plats futurs i mostrar «Cambiar». Obrir les alternatives i confirmar-ne una si hi ha temps.]

Si un plat futur no convenç el client, pot tocar «Cambiar», mirar alternatives compatibles i confirmar-ne una. Aquest canvi queda guardat directament i no torna a la cua de l'operari. Hem limitat l'acció a dates futures, perquè canviar sobre el paper un àpat que ja ha passat no tindria sentit.

El client també pot opinar sobre un plat d'avui o d'un dia anterior. Aquesta opinió serveix per influir en propostes posteriors. De nou, distingim entre preferència i restricció: una valoració negativa no elimina automàticament un ingredient com si fos un al·lergen.

Aquest recorregut ens ha ajudat a concretar el producte. La persona controla el calendari i pot rectificar un plat; l'operari només intervé en el primer menú. El prototip ja permet mostrar aquestes pantalles i aquestes transicions de principi a fi en el mode de proves.»

**Traspàs:** «[Nom de la persona 4], explica'ns ara on encaixa la IA i quin és l'estat real de la integració.»

## Diapositiva 2 — IA, eines i estat

### Persona 4 · 7:15–10:00 · Funció de la IA i tancament

[Passar a la diapositiva 2.]

«La funció prevista per a la IA és proposar un plat per a cada data i àpat, tenint en compte el perfil i la varietat. Primer, el servidor filtra el catàleg segons les restriccions declarades. Després envia al model els candidats i els espais del menú. Finalment, valida que els codis retornats existeixen, encaixen en l'àpat i respecten les restriccions. Una resposta incompleta o invàlida es rebutja.

La demostració que heu vist utilitza un generador local determinista, en mode de proves, **sense IA**. Hem implementat l'adaptador de Groq i l'hem provat amb una resposta simulada, però encara no hem verificat una generació mensual amb una crida real. Avui podem defensar el recorregut digital i les comprovacions del servidor; no podem afirmar que la generació amb IA real estigui validada. El següent pas és repetir el recorregut amb el mode d'IA activat.

Hem utilitzat Codex per programar, revisar el codi i preparar la documentació de la demo. Les decisions de producte i la responsabilitat sobre el resultat són del grup. La interfície indica quan una proposta surt del mode de proves.

També tenim pendent fer dues proves amb persones externes i incorporar almenys una millora basada en les seves observacions. Volem veure si entenen, sense ajuda, la diferència entre configurar el perfil, esperar l'aprovació i canviar un plat futur.

En resum, Easy Eats transforma les decisions del client en un menú mensual consultable per setmanes. Hem mostrat el recorregut del client, la revisió de l'operari i el canvi d'un plat. Els següents passos són validar la crida real d'IA i corregir allò que detectem a les proves amb persones. Gràcies.»

## Control del temps

| Tram | Durada | Senyal per avançar |
| --- | ---: | --- |
| Persona 1 | 2:15 | Cedir la web al client |
| Persona 2 | 2:25 | Mostrar «pendent de revisió» |
| Persona 3 | 2:35 | Acabar amb el canvi de plat futur |
| Persona 4 | 2:45 | Tancar a 10:00 |

Si la demostració es retarda, ometeu el clic de confirmació del canvi i deixeu visibles les alternatives. Manteniu sempre l'explicació de l'estat real de la IA i de les proves pendents.
