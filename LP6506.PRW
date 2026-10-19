/*
+----------+----------+-------+--------------------------------------------------------------+------+------------+
| Funcao   |LP6506  | Autor | Karina Bittencourt                                             | Data | 18/06/2026 |
+----------+----------+-------+--------------------------------------------------------------+------+------------+
|Descricao: conta contábil de débito - Aquisicao de Servicos 650/006                                         |
+---------------------+------------------------------------------------------------------------------------------+
|Uso especi�fico na Valenet                                                                                       |
+----------+----------+------------------------------------------------------------------------------------------+  
*/

User Function LP6506()

    Local cItem   := AllTrim(SD1->D1_ITEMCTA)
    Local cCateg  := AllTrim(Posicione("CTT",1,XFILIAL("CTT")+SD1->D1_CC,"CTT_ZCATEG"))

    If Left(cItem,1) == 'O' .OR. cItem == "P250037" .OR. cItem == "P260051"
        Return '1240106001'
    EndIf

    If Left(cItem,2) == 'RH'
        Return SD1->D1_CONTA
    EndIf

    If SF4->F4_ATUATF == "S"
        Return SB1->B1_CONTA1
    EndIf

    Do Case
        Case cCateg == 'O'
            Return SB1->B1_CONTA2
        Case cCateg == 'C'
            Return SB1->B1_CONTA3
        Case cCateg == 'A'
            Return SB1->B1_CONTA4
    EndCase

Return ''

                                                                                                                                                                                                 
