$ErrorActionPreference = "Stop"

$buildDirectory = Join-Path $env:TEMP "cmod-rv32ima-tests"
New-Item -ItemType Directory -Force -Path $buildDirectory | Out-Null

$commonSources = @(
    (Join-Path $PSScriptRoot "rv32ima_pkg.sv"),
    (Join-Path $PSScriptRoot "rv32_muldiv.sv"),
    (Join-Path $PSScriptRoot "sv32_mmu.sv"),
    (Join-Path $PSScriptRoot "rv32ima_core.sv")
)

function Invoke-IcarusTest {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Top,
        [Parameter(Mandatory = $true)]
        [string[]] $Sources
    )

    $output = Join-Path $buildDirectory "$Top.vvp"
    & iverilog -g2012 -s $Top -o $output $Sources
    if ($LASTEXITCODE -ne 0) {
        throw "Icarus compilation failed for $Top"
    }

    & vvp $output
    if ($LASTEXITCODE -ne 0) {
        throw "Simulation failed for $Top"
    }
}

Invoke-IcarusTest "rv32_muldiv_tb" @(
    (Join-Path $PSScriptRoot "rv32_muldiv.sv"),
    (Join-Path $PSScriptRoot "rv32_muldiv_tb.sv")
)
Invoke-IcarusTest "sv32_mmu_tb" @(
    (Join-Path $PSScriptRoot "rv32ima_pkg.sv"),
    (Join-Path $PSScriptRoot "sv32_mmu.sv"),
    (Join-Path $PSScriptRoot "sv32_mmu_tb.sv")
)

$coreTests = @(
    "rv32ima_core_tb",
    "rv32ima_atomic_tb",
    "rv32ima_alignment_tb",
    "rv32ima_no_compressed_tb",
    "rv32ima_interrupt_tb",
    "rv32ima_privilege_tb"
)
foreach ($test in $coreTests) {
    Invoke-IcarusTest $test (
        $commonSources + (Join-Path $PSScriptRoot "$test.sv")
    )
}

Write-Host "All RV32IMA tests passed."
