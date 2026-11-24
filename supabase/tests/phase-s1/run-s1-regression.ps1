$ErrorActionPreference = 'Stop'
$Container = 'supabase_db_BizHunt-Local-Test'
Set-Location -LiteralPath $PSScriptRoot
$env:DOCKER_CONTEXT = 'desktop-linux'
Remove-Item Env:DOCKER_HOST -ErrorAction SilentlyContinue
$log = Join-Path $PSScriptRoot ('regression-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')
function Log($Message) { $Message | Tee-Object -FilePath $log -Append | Write-Host }
$stages = @(
    @{File='s1-regression-stage1-v2.sql'; Count=16; Hash='9A78D97EDF35073837CF449214C72496E82404DB66272BA93A8B874015C78906'}
    @{File='s1-regression-stage2.sql'; Count=13; Hash='4885F69DFC93111855FCFAE9F8DDF1DA9F1962B0FB95D2D322F0932A251D7239'}
    @{File='s1-regression-stage3.sql'; Count=14; Hash='572ABC216BEC00B1B31C3F7BCA03D406F4A07F7425F1B13F243DE76B600F242D'}
    @{File='s1-regression-stage4.sql'; Count=14; Hash='8E82BF7D8BA06FF35B1F99396A28170837BD3019440F83B8B280ADD4F6B00CDC'}
    @{File='s1-regression-stage5.sql'; Count=14; Hash='A6AEE36D0729CF79BC17C59A42303D01F03858EF5D452AB98154AF35FE82AEF6'}
 )
try {
    $state = docker inspect --format '{{.State.Running}}' $Container
    if ($LASTEXITCODE -ne 0 -or $state -ne 'true') { throw 'Expected local Docker container is not running.' }
    foreach ($stage in $stages) {
        if ((Get-FileHash -LiteralPath $stage.File -Algorithm SHA256).Hash -ne $stage.Hash) { throw "Unexpected script version: $($stage.File)" }
    }
    $total = 0
    foreach ($stage in $stages) {
        Log "Running $($stage.File)"
        $remote = '/tmp/' + $stage.File
        docker cp $stage.File "${Container}:$remote"
        if ($LASTEXITCODE -ne 0) { throw 'Docker copy failed.' }
        # Capture native stderr (psql NOTICE messages) without treating it as a PowerShell error.
        $old = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $output = @(docker exec $Container psql -X -U postgres -d postgres -v ON_ERROR_STOP=1 -f $remote 2>&1 | ForEach-Object { $_.ToString() })
            $code = $LASTEXITCODE
        } finally { $ErrorActionPreference = $old }
        $output | ForEach-Object { Log $_ }
        $ids = @($output | ForEach-Object { if ($_ -match 'NOTICE:\s+PASS (\d+):') { [int]$Matches[1] } })
        $expected = 1..$stage.Count
        if ($code -ne 0 -or ($ids -join ',') -ne ($expected -join ',') -or -not ($output -contains 'ROLLBACK')) { throw "Stage failed: $($stage.File), exit $code, PASS count $($ids.Count)" }
        $total += $ids.Count
        Log "Stage passed: $($ids.Count)/$($stage.Count)"
    }
    Log "SUCCESS: $total/71 checkpoints passed."
    exit 0
} catch {
    Log "FAILED: $_"
    exit 1
}
