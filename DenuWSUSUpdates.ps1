<#
    Очистка WSUS-сервера от ненужных обновлений.
    Названия ($_.Update.Title) всех утвержденных обновлений сравниваются сначала с белым списком обновлений, потом с черным.
    Если обновление в белом списке, то оно оставляется. 
    Белый список имеет приоритет над черным.
    Только если обновление не попало в белый список оно сравнивается с черным списком.
    Обновления которые соответствуют черному списку отклоняются
    Если есть ключ -Force то обновления отклоняются, если его нет, то только показывается список обновлений-кандидатов на отклонение
#>

#$Updates = Get-WsusUpdate -Approval $StatusApproved -Classification $StatusClassification -Status $StatusStatus | Where-Object {$_.Update.Title -like "$strFragmentTitle"}

Param(
    $StatusApproved = "Approved",  # Approved, Unapproved, AnyExceptDeclined, Declined
    $StatusClassification = "All", # All, Critical, Security, WSUS
    $StatusStatus = "Any",  # NoStatus, InstalledOrNotApplicable, InstalledOrNotApplicableOrNotStatus, Failed, Needed, FailedOrNotNeeded, Any
    [switch]$Force          # Если есть, то реально отклоняет обновления, если нет, то только выводит список обновлений которых надо отклонить
    )

#Get-WsusUpdate -Approval Approved -Classification All -Status Any | Where-Object {$_.Update.Title -like "*arm64*"} | Deny-WsusUpdate -Confirm

#Белый список обновлений. Можно использовать подстановочные символы типа *. И даже нужно.
#Ооочень рекомендуется делать каждый шаблон как можно больше
$AlloweUpdatesPatterns = 
    "*NET Framework*Windows 7*",
    "*Windows 7*NET Framework*",
    "*Powershell*Windows 7*",
    "*Windows 7*Powershell*"
    "" # Добавляйте НАД ЭТОЙ СТРОКОЙ. Тут пустая строка всегда должна быть

#Черный список обновлений. Можно использовать подстановочные символы типа *. И даже нужно.
$DenyUpdatesPatterns = 
    "*ARM64*",
    "*Itanium*",
    "*IA64*",
    "*Embedded*",
    "*Windows 7*02 2021*",
    "*Windows 7*03 2021*",
    "*Windows 7*04 2021*",
    "*Windows 7*05 2021*",
    "*Windows 7*06 2021*",
    "*Windows 7*07 2021*",
    "*Windows 7*08 2021*",
    "*Windows 7*09 2021*",
    "*Windows 7*10 2021*",
    "*Windows 7*11 2021*",
    "*Windows 7*12 2021*",
    "*Windows 7*2021-02*",
    "*Windows 7*2021-03*",
    "*Windows 7*2021-04*",
    "*Windows 7*2021-05*",
    "*Windows 7*2021-06*",
    "*Windows 7*2021-07*",
    "*Windows 7*2021-08*",
    "*Windows 7*2021-09*",
    "*Windows 7*2021-10*",
    "*Windows 7*2021-11*",
    "*Windows 7*2021-12*",
    "*Windows 7*2022*",
    "*Windows 7*2023*",
    "*Windows 7*2024*"

$Script:CountAllUpdates = 0
$Script:CountPatternUpdates = 0

#Возвращает только обновления которые можно блокировать-отклонять
function Select-UpdateByTitle(){

    Begin {
        $Script:CountAllUpdates = 0
        $Script:CountPatternUpdates = 0
    }

    Process {

        $Script:CountAllUpdates++
        $UpdateTitle = $_.Update.Title

        [bool]$isWhiteUpdate = $false

        if($AlloweUpdatesPatterns.Count -gt 0){
            ForEach($I in $AlloweUpdatesPatterns){
                if(($UpdateTitle -like "$I") -and ("$I" -ne "")){
                    $isWhiteUpdate = $True
                    Break
                }
            }
        }

        if(( -not $isWhiteUpdate ) -and ($DenyUpdatesPatterns.Count -gt 0)){
            ForEach($I in $DenyUpdatesPatterns){
                if($UpdateTitle -like "$I"){
                    $Script:CountPatternUpdates++
                    $_
                    Break
                }
            }#ForEach($I in $DenyUpdatesPatterns)
        }#if( -not $isWhiteUpdate )
    }

    End {}
}

$watch = [System.Diagnostics.Stopwatch]::StartNew()
$watch.Start() #Запуск таймера

Write-Host "Поиск обновлений которые можно отклонять"
$DenyUpdates = Get-WsusUpdate -Approval $StatusApproved -Classification $StatusClassification -Status $StatusStatus | Select-UpdateByTitle
Write-Warning "Список обновлений которые можно отклонять. Если какие-то обновления надо оставить, добавь их шаблон в массив AlloweUpdatesPatterns"
$DenyUpdates.Update.Title
if($Force){
    Write-Warning "Отклоняю обновления"
    #$DenyUpdates | Deny-WsusUpdate
}else{
    Write-Host "Просто вывожу список обновлений на отклонение. Для отклонения воспользуйся параметром -Force"
}

Write-Host "Всего обработано обновлений" $Script:CountAllUpdates
Write-Host "Из них подпало под шаблон" $Script:CountPatternUpdates

$watch.Stop() #Остановка таймера
Write-Host "Время поиска и отклонения обновлений" $watch.Elapsed #Время выполнения


