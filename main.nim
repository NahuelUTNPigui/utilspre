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
    


proc test()=
    let client = newHttpClient()
    client.headers = newHttpHeaders({ "Content-Type": "application/json","Authorization":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJjb2xsZWN0aW9uSWQiOiJfcGJfdXNlcnNfYXV0aF8iLCJleHAiOjE3MTI0MzI5NjcsImlkIjoiazl2ejg1NHR2OGFzaXVpIiwidHlwZSI6ImF1dGhSZWNvcmQifQ.uD-av6JZFIQfrZGI4isx6wFCqTe-UoEtnz6ICXXfTTU" })
    try:
        var response = client.request("http://localhost:8090/api/collections/Remitente/records?perPage=1&page=1")
        var resrem = fromJson($response.body,ResRemitente)
        var rems:seq[Remitente] = @[]
        var paginas = 1 + resrem.totalItems div 200
        for pag in countup(1,paginas):
            response = client.request("http://localhost:8090/api/collections/Remitente/records?perPage=200&page=" & $pag)
            resrem = fromJson($response.body,ResRemitente)
            for re in resrem.items:
                rems.add(re)

        for r in rems:
            echo r.showRem()
    finally:
        client.close()
proc leerauth():string=
    let client = newHttpClient()
    client.headers = newHttpHeaders({ "Content-Type": "application/json" })
    var reqauth = AuthRequest(identity:"nahue@nahue.com",password:"nahue12345")
    var response = client.request("http://localhost:8090/api/collections/users/auth-with-password",httpMethod=HttpPost,body=toJson(reqauth))
    var resauth = fromJson($response.body,ResAuth)
    return resauth.token
proc main1()=
    let client = newHttpClient()
    var auth = leerauth()
    client.headers = newHttpHeaders({ "Content-Type": "application/json","Authorization":auth })
    try:        
        var clientes:seq[Cliente] = @[]
        var response = client.request("http://localhost:8090/api/collections/Cliente/records?perPage=1&page=1")

        var resclientes = fromJson($response.body,ResCliente)
        var paginas = 1 + resclientes.totalItems div 200
        for pag in countup(1,paginas):
            response = client.request("http://localhost:8090/api/collections/Cliente/records?perPage=200&page=" & $pag)
            resclientes = fromJson($response.body,ResCliente)
            for cl in resclientes.items:
                clientes.add(cl)

        for cl in clientes:
            echo "id: " & $cl.id
            response = client.request("http://localhost:8090/api/collections/Remitente/records?perPage=200&page=1&filter=(cliente='" & cl.id & "')")            
            var resremitente = fromJson($response.body,ResRemitente)
            echo resremitente.showRes
            echo "Remitentes"
            for re in resremitente.items:
                response = client.request("http://localhost:8090/api/collections/RemitenteXCliente/records?expand=remitente&filter=(remitente.nombre='" & re.nombre.replace(" ","%20") & "'%26%26cliente='" & cl.id & "')&perPage=200&page=1")                
                var resrxc = fromJson($response.body,ResRemXCli)
                echo "se ejecuto el resrxc"
                if resrxc.totalItems == 0:
                    response = client.request("http://localhost:8090/api/collections/Remitente/records?filter=(nombre='" & re.nombre.replace(" ","%20") & "')&perPage=200&page=1")                    
                    var resremrepetidos = fromJson($response.body,ResRemitente)
                    echo "Remitentes repetidos"
                    for rer in resremrepetidos.items:
                        var respatch = client.request("http://localhost:8090/api/collections/Remitente/records/" & $rer.id,httpMethod=HttpPatch,body=toJson(Activo(active:false)))
                        var rxcfila = newRemXCliente(re.id,cl.id)
                        # aca esta el problema
                        var respost = client.request("http://localhost:8090/api/collections/RemitenteXCliente/records",httpMethod=HttpPost,body=toJson(rxcfila))
                        response = client.request("http://localhost:8090/api/collections/Remito/records?filter=(remitente='" & rer.id & "')&perPage=200&page=1")
                        echo "Remitos"
                        var resremito = fromJson($response.body,ResRemito)
                        for remito in resremito.items:
                            var resremitopatch = client.request("http://localhost:8090/api/collections/Remito/records/" & $remito.id,httpMethod=HttpPatch,body=toJson(RemitenteRemito(remitente:re.id)))
                            echo "remito: " & $remito.id
                    var respatch = client.request("http://localhost:8090/api/collections/Remitente/records/" & $re.id,httpMethod=HttpPatch,body=toJson(Activo(active:true)))
                    echo "respatch"
    except CatchableError as e:
        echo "Murio en madrid"
        echo e.msg
    finally:
        client.close()
        echo "Termino ejecutarse"

proc main2()=
    let httpclient = newHttpClient()
    var auth = leerauth()
    httpclient.headers = newHttpHeaders({ "Content-Type": "application/json","Authorization":auth })
    var response = httpclient.request("http://preventa.local/api/collections/Remitente/records?perPage=200&page=1")
    var resremitente = fromJson($response.body,ResRemitente)
    echo "Resremitente"
    for re in resremitente.items:
        response = httpclient.request("http://preventa.local/api/collections/Remitente/records/" & re.id)
        var remitente = fromJson($response.body,Remitente)
        if remitente.active:
            response = httpclient.request("http://preventa.local/api/collections/Remitente/records?perPage=200&page=1&filter=(nombre='" & re.nombre.replace(" ","%20") & "')")
            var resremitenterepetido = fromJson($response.body,ResRemitente)
            for rer in resremitenterepetido.items:
                var respatch = httpclient.request("http://preventa.local/api/collections/Remitente/records/" & $rer.id,httpMethod=HttpPatch,body=toJson(Activo(active:false)))
                var rxcfila = newRemXCliente(re.id,rer.cliente)
                var respost = httpclient.request("http://preventa.local/api/collections/RemitenteXCliente/records",httpMethod=HttpPost,body=toJson(rxcfila))
                response = httpclient.request("http://preventa.local/api/collections/Remito/records?filter=(remitente='" & rer.id & "')&perPage=200&page=1")
                var resremito = fromJson($response.body,ResRemito)
                for remito in resremito.items:
                    var resremitopatch = httpclient.request("http://preventa.local/api/collections/Remito/records/" & $remito.id,httpMethod=HttpPatch,body=toJson(RemitenteRemito(remitente:re.id)))
                    echo "remito: " & $remito.id
            var respatch = httpclient.request("http://preventa.local/api/collections/Remitente/records/" & $re.id,httpMethod=HttpPatch,body=toJson(Activo(active:true)))
            echo "respatch"

main2()