http://localhost:6210/crypto/signMSG

{
    "obj":"fuck you",
    "cert_sn":"718A2566C237970F",
    "cert_thumb":"EF779FA0860EC20D5A8A6F23D3A323F9EC70A1FC",
    "cms":"false",
    "detached":"false",
    "codepage": "1251"
}

curl -X POST "http://localhost:6210/crypto/signMSG" -H "Content-Type: application/json" -d "{\"obj\":\"fuck you\",\"cert_sn\":\"718A2566C237970F\",\"cert_thumb\":\"EF779FA0860EC20D5A8A6F23D3A323F9EC70A1FC\",\"cms\":\"false\",\"detached\":\"false\",\"codepage\":\"1251\"}"

curl -X POST "http://ip:port/TransCryptAS/VerifyAndGetCmsContent" -H "Content-Type: application/json" -d "{\"cms\":\"\"}"
