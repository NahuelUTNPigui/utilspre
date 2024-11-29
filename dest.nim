import std/httpclient
import jsony
import strutils
import csvtools

const prod = "http://preventa.local"
const local = "http://localhost:8090"

type Localidad = object
    nombre:string

type Expandir = object
    localidad:Localidad

type Destinatario = object
    id:string
    nombre:string
    observacion:string
    horarios:string
    direccion:string
    expand:Expandir
    localidad:string

type DestCsv = object
    id:string
    nombre:string
    observacion:string
    horarios:string
    direccion:string
    localidad:string

type ResDest = object
    totalItems:int
    items:seq[Destinatario]

type AuthRequest = object
    identity:string
    password:string

type ResAuth = object
    token:string


proc toCsv(d:Destinatario):DestCsv=
    DestCsv(
        id:d.id,
        nombre:d.nombre,
        observacion:d.observacion,
        horarios:d.horarios,
        direccion:d.direccion,
        localidad:d.expand.localidad.nombre,
    )

proc leerauth():string=
    let client = newHttpClient()
    client.headers = newHttpHeaders({ "Content-Type": "application/json" })
    var reqauth = AuthRequest(identity:"nahue@nahue.com",password:"nahue12345")
    var response = client.request("http://localhost:8090/api/collections/users/auth-with-password",httpMethod=HttpPost,body=toJson(reqauth))
    var resauth = fromJson($response.body,ResAuth)
    return resauth.token

proc main(esProd:bool)=
    let httpclient = newHttpClient()
    var auth = leerauth()
    httpclient.headers = newHttpHeaders({ "Content-Type": "application/json","Authorization":auth })
    var urld = local
    if esProd:
        urld = prod
    urld &= "/api/collections/Destinatario/records?perPage=1&page=1&filter=(active=True)&expand=localidad"
    var responsed = httpclient.request(urld)
    var resdest = fromJson($responsed.body,ResDest)
    let perPage:int = 200
    let paginas:int = resdest.totalItems div perPage + 1
    var dest:seq[DestCsv] = @[]
    for p in countup(1,paginas):
        var url = local
        if esProd:
            url = prod
        url &= "/api/collections/Destinatario/records?perPage=200&page=" & $p & "&filter=(active=True)&expand=localidad"
        var response = httpclient.request(url)
        var res = fromJson($response.body,ResDest)
        for d in res.items:
            dest.add(toCsv(d))
    dest.writeToCsv("dest.csv")
    
    

main(false)

