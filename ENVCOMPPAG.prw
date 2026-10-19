#Include "PRTOPDEF.CH"
#Include "Protheus.ch"
#Include "TopConn.ch"

/*
+----------+----------+-------+--------------------------------------------------------------+------+------------+
| Funcao   |LP6506    | Autor | Karina Bittencourt                                           | Data | 04/09/2026 |
+----------+----------+-------+--------------------------------------------------------------+------+------------+
|Envio de comprovante de pagamento para o fornecedor                                                             |
+---------------------+------------------------------------------------------------------------------------------+
*/

User Function ENVPGTO(cEmpProc, cFilProc)

    Local lRpc      := .F.
    Local cQuery    := ""
    Local nEnviados := 0
    Local nFalhas   := 0

    // Se for chamado via Scheduler, prepara a empresa/filial no ambiente
    If Type("cEmpProc") == "C" .And. Type("cFilProc") == "C"
        lRpc := .T.
        RPCSetEnv(cEmpProc, cFilProc)
    EndIf

    cQuery := " SELECT "
    cQuery += " E5.E5_FILIAL, E5.E5_PREFIXO, E5.E5_NUMERO, E5.E5_CLIFOR, E5.E5_LOJA, "
    cQuery += " E2.E2_FORNECE, E2.E2_NUM, E2.E2_NOMFOR, E2.E2_VALOR, E2.E2_BAIXA, "
    cQuery += " A2.A2_EMAIL, A2.A2_CGC "
    cQuery += " FROM " + RetSqlName("SE5") + " E5 "
    cQuery += " INNER JOIN " + RetSqlName("SE2") + " E2 "
    cQuery += "   ON E2.E2_FILIAL  = E5.E5_FILIAL "
    cQuery += "  AND E2.E2_PREFIXO = E5.E5_PREFIXO "
    cQuery += "  AND E2.E2_NUM     = E5.E5_NUMERO "
    cQuery += "  AND E2.E2_FORNECE = E5.E5_CLIFOR "
    cQuery += "  AND E2.E2_LOJA    = E5.E5_LOJA "
    cQuery += "  AND E2.D_E_L_E_T_ = '' "
    cQuery += " INNER JOIN " + RetSqlName("SA2") + " A2 "
    cQuery += "   ON A2.A2_COD    = E2.E2_FORNECE "
    cQuery += "  AND A2.A2_LOJA   = E2.E2_LOJA "
    cQuery += "  AND A2.D_E_L_E_T_ = '' "
    cQuery += " WHERE E5.D_E_L_E_T_   = '' "
    cQuery += "   AND E5.E5_DTDISPO = '" + DTOS(Date()) + "' "
    cQuery += "   AND E5.E5_MOTBX   = 'DEB' "

    cQuery := ChangeQuery(cQuery)

    If Select("QRY") > 0
        QRY->(DbCloseArea())
    EndIf

    DbUseArea(.T., "TOPCONN", TcGenQry(,,cQuery), "QRY", .F., .T.)

    If QRY->(Eof())
        ConOut("[ENVPGTO] Nenhum pagamento encontrado para a data atual.")
        QRY->(DbCloseArea())
        If lRpc
            RpcClearEnv()
        EndIf
        Return
    EndIf

    ConOut("[ENVPGTO] Iniciando processamento de envio...")
    ProcEnvio(@nEnviados, @nFalhas)
    ConOut("[ENVPGTO] Envio finalizado.")

    QRY->(DbCloseArea())

    ConOut("[ENVPGTO] Resultado do Processamento:")
    ConOut("[ENVPGTO] Enviados com sucesso: " + cValToChar(nEnviados))
    ConOut("[ENVPGTO] Falhas no envio:     " + cValToChar(nFalhas))

    If lRpc
        RpcClearEnv()
    EndIf

Return

Static Function ProcEnvio(nEnviados, nFalhas)

    Local cMail      := ""
    Local cAssunto   := ""
    Local cHtml      := ""
    Local cDataBaixa := ""
    Local aMails     := {}
    Local nI         := 0
    Local cMailAtual := ""
    Local lSucesso   := .F.
    Local cLogErros  := ""

    Local oServer  := TMailManager():New()
    Local oMessage := TMailMessage():New()
    Local nErr     := 0

    Local cServer := "email-smtp.us-west-2.amazonaws.com"
    Local cFrom   := "protheus@valenet.com.br"
    Local cUser   := "AKIA46WOPDDJQVBA4QJ3"
    Local cPass   := "BCFMxNNYo+JGQwqXXr2E/D7pZYPiOiT6Zb91zi2H2ikR" 
    Local nPort   := 465

    oServer:SetUseSSL(.T.)
    oServer:SetUseTLS(.F.)
    oServer:SetSmtpTimeOut(60)

    // Inicializa
    nErr := oServer:Init("", cServer, cUser, cPass, 0, nPort)
    If nErr <> 0
        ConOut("[ENVPGTO][ERRO] Erro Init SMTP: " + cValToChar(nErr))
        Return
    EndIf

    // Conecta
    nErr := oServer:SmtpConnect()
    If nErr <> 0
        ConOut("[ENVPGTO][ERRO] Erro Connect: " + cValToChar(nErr) + " - " + oServer:GetErrorString(nErr))
        Return
    EndIf

    // Autentica
    nErr := oServer:SmtpAuth(cUser, cPass)
    If nErr <> 0
        ConOut("[ENVPGTO][ERRO] Erro Auth: " + cValToChar(nErr) + " - " + oServer:GetErrorString(nErr))
        oServer:SmtpDisconnect()
        Return
    EndIf

    While !QRY->(Eof())

        cMail := AllTrim(QRY->A2_EMAIL)

        If Empty(cMail) .Or. !("@" $ cMail)
            nFalhas++
            cLogErros += "Título " + AllTrim(QRY->E2_NUM) + " - e-mail inválido." + CRLF
            QRY->(DbSkip())
            Loop
        EndIf

        cAssunto := "Comprovante de Pagamento - Título " + AllTrim(QRY->E2_NUM)

        If ValType(QRY->E2_BAIXA) == "D"
            cDataBaixa := DToC(QRY->E2_BAIXA)
        Else
            cDataBaixa := DToC(SToD(QRY->E2_BAIXA))
        EndIf

        cHtml := "<html><body><font face='Arial'>"
        cHtml += "Prezado(a),<br><br>"
        cHtml += "Informamos que o pagamento referente ao título <b>" + AllTrim(QRY->E2_NUM) + "</b> foi realizado.<br><br>"
        cHtml += "Fornecedor: <b>" + AllTrim(QRY->E2_NOMFOR) + "</b><br>"
        cHtml += "CNPJ/CPF: <b>" + AllTrim(QRY->A2_CGC) + "</b><br>"
        cHtml += "Título: <b>" + AllTrim(QRY->E2_NUM) + "</b><br>"
        cHtml += "Data: <b>" + cDataBaixa + "</b><br>"
        cHtml += "Valor: <b>R$ " + Transform(QRY->E2_VALOR, "@E 999,999,999.99") + "</b><br><br>"
        cHtml += "Atenciosamente,<br>Equipe Valenet"
        cHtml += "</font></body></html>"

        cMail  := StrTran(cMail, ",", ";")
        aMails := Separa(cMail, ";")

        lSucesso := .F.

        For nI := 1 To Len(aMails)

            cMailAtual := AllTrim(aMails[nI])

            If Empty(cMailAtual)
                Loop
            EndIf

            oMessage:Clear()
            oMessage:cFrom     := cFrom
            oMessage:cTo       := cMailAtual
            oMessage:cSubject  := cAssunto
            oMessage:cBody     := cHtml
            oMessage:MsgBodyType("text/html")

            nErr := oMessage:Send(oServer)

            ConOut("=== ENVPGTO SMTP ===")
            ConOut("Título: " + AllTrim(QRY->E2_NUM))
            ConOut("Destino: " + cMailAtual)
            ConOut("Retorno: " + cValToChar(nErr))
            ConOut("Mensagem: " + oServer:GetErrorString(nErr))

            If nErr == 0
                lSucesso := .T.
            Else
                cLogErros += "Título " + AllTrim(QRY->E2_NUM) + " (" + cMailAtual + ") - Erro " + cValToChar(nErr) + " - " + oServer:GetErrorString(nErr) + CRLF
            EndIf

        Next

        If lSucesso
            nEnviados++
        Else
            nFalhas++
        EndIf

        QRY->(DbSkip())

    EndDo

    oServer:SmtpDisconnect()

    If !Empty(cLogErros)
        ConOut("Falhas de envio")
        ConOut(cLogErros)
    EndIf

Return
