import std/httpclient
import jsony
import strutils
type Remitente = object
    nombre:string
    id:string
    cliente:string
    active:bool

type ResRemitente = object
    totalItems:int
    items:seq[Remitente]

type Cliente = object
    id : string
    nombre : string

type Remito = object
    id:string

type RemitenteRemito = object
    remitente : string
type ResCliente = object
    totalItems:int
    items:seq[Cliente]

type ResRemito = object
    totalItems:int
    items:seq[Remito]

type Activo = object
    active : bool

type RemitenteXCliente = object
    remitente:string
    cliente:string

type ResRemXCli = object
    totalItems:int
    items:seq[RemitenteXCliente]

type AuthRequest = object
    identity:string
    password:string

type ResAuth = object
    token:string

proc newRemXCliente(remitente,cliente:string):RemitenteXCliente=
    RemitenteXCliente(remitente:remitente,cliente:cliente)


proc showRem(rem:Remitente) : string =
    
    var s = " { id: " & $rem.id
    s &= " , nombre: " & $rem.nombre
    s &= " , cliente: " & $rem.cliente
    s &= "}"
    return s

proc showRes(res:ResRemitente):string=
    var s = "Total items: " & $res.totalItems & "\n"
    for i in res.items:
        s &= "\t rem: " & i.showRem & "\n"
    return s
    
proc leerauth():string=
    let client = newHttpClient()
    client.headers = newHttpHeaders({ "Content-Type": "application/json" })
    var reqauth = AuthRequest(identity:"nahue@nahue.com",password:"nahue12345")
    var response = client.request("http://localhost:8090/api/collections/users/auth-with-password",httpMethod=HttpPost,body=toJson(reqauth))
    var resauth = fromJson($response.body,ResAuth)
    return resauth.token
proc main()=
    let httpclient = newHttpClient()
    var auth = leerauth()
    httpclient.headers = newHttpHeaders({ "Content-Type": "application/json","Authorization":auth })
    var response = httpclient.request("http://localhost:8090/api/collections/Remitente/records?perPage=200&page=1")
    var resremitente = fromJson($response.body,ResRemitente)
    echo "Resremitente"
    for re in resremitente.items:
        response = httpclient.request("http://localhost:8090/api/collections/Remitente/records/" & re.id)
        var remitente = fromJson($response.body,Remitente)
        if remitente.active:
            response = httpclient.request("http://localhost:8090/api/collections/Remitente/records?perPage=200&page=1&filter=(nombre='" & re.nombre.replace(" ","%20") & "')")
            var resremitenterepetido = fromJson($response.body,ResRemitente)
            for rer in resremitenterepetido.items:
                var respatch = httpclient.request("http://localhost:8090/api/collections/Remitente/records/" & $rer.id,httpMethod=HttpPatch,body=toJson(Activo(active:false)))
                var rxcfila = newRemXCliente(re.id,rer.cliente)
                var respost = httpclient.request("http://localhost:8090/api/collections/RemitenteXCliente/records",httpMethod=HttpPost,body=toJson(rxcfila))
                response = httpclient.request("http://localhost:8090/api/collections/Remito/records?filter=(remitente='" & rer.id & "')&perPage=200&page=1")
                var resremito = fromJson($response.body,ResRemito)
                for remito in resremito.items:
                    var resremitopatch = httpclient.request("http://localhost:8090/api/collections/Remito/records/" & $remito.id,httpMethod=HttpPatch,body=toJson(RemitenteRemito(remitente:re.id)))
                    echo "remito: " & $remito.id
            var respatch = httpclient.request("http://localhost:8090/api/collections/Remitente/records/" & $re.id,httpMethod=HttpPatch,body=toJson(Activo(active:true)))
            echo "respatch"

main()