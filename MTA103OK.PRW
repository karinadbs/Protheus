#Include 'Protheus.ch'

/*
+----------+----------+-------+--------------------------------------------------------------+------+------------+
| Funcao   |MTA105LIN | Autor | Karina Bittencourt                                           | Data | 14/09/2026 |
+----------+----------+-------+--------------------------------------------------------------+------+------------+
|Descricao: Valida a obrigatoriedade do Rateio por Centro de Custo.                                              |
+---------------------+------------------------------------------------------------------------------------------+
|Uso especifico na Valenet                                                                                       |
+----------+----------+------------------------------------------------------------------------------------------+  
*/

User Function MTA103OK()
    Local lRet       := .T.
    Local nI         := 0
    Local nJ         := 0
    Local nPosRat    := GDFieldPos("D1_RATEIO")
    Local aRateios   := {}
    Local nQtdRat    := 0

    // Tenta capturar aColsSDE da memória com segurança para evitar o THREAD ERROR
    If Type("aColsSDE") == "A"
        aRateios := aColsSDE
    ElseIf Type("M->aColsSDE") == "A"
        aRateios := M->aColsSDE
    EndIf

    // 1. Se os rateios estão na memória em aRateios
    If Len(aRateios) > 0
        For nI := 1 To Len(aCols)
            If !aCols[nI, Len(aHeader) + 1] // Linha não deletada
                nQtdRat := 0
                For nJ := 1 To Len(aRateios)
                    // Verifica se pertence ao item e não está deletada na grid do rateio
                    If aRateios[nJ, 1] == nI .And. !aRateios[nJ, Len(aRateios[nJ])]
                        nQtdRat++
                    EndIf
                Next nJ

                If nQtdRat == 0
                    Help(, 1, "MTA103OK",, "O item " + cValToChar(nI) + " não possui Rateio por Centro de Custo informado.", 1, 0)
                    Return .F.
                EndIf
            EndIf
        Next nI

    // 2. Fallback: Se aColsSDE não estiver na memória, valida pelo campo D1_RATEIO no aCols
    Else
        For nI := 1 To Len(aCols)
            If !aCols[nI, Len(aHeader) + 1]
                // Se existir o campo D1_RATEIO na grid, valida se está preenchido com '1' (Sim)
                If nPosRat > 0
                    If aCols[nI, nPosRat] != "1"
                        Help(, 1, "MTA103OK",, "O item " + cValToChar(nI) + " precisa ter Rateio por Centro de Custo.", 1, 0)
                        Return .F.
                    EndIf
                Else
                    // Se não encontrou o vetor de rateio e nem o campo D1_RATEIO
                    Help(, 1, "MTA103OK",, "Não foram encontrados lançamentos de Rateio por Centro de Custo para este documento.", 1, 0)
                    Return .F.
                EndIf
            EndIf
        Next nI
    EndIf

Return lRet
