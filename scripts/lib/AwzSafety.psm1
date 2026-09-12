Set-StrictMode -Version Latest

function Get-AwzFullPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "Refusing an empty filesystem path."
    }

    return [IO.Path]::GetFullPath($Path).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
}

function Assert-AwzSafeRemovalTarget {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$AllowedRoot,

        [string]$TopLevelPrefix = "smoke-"
    )

    $allowed = Get-AwzFullPath -Path $AllowedRoot
    $target = Get-AwzFullPath -Path $Path
    $separator = [IO.Path]::DirectorySeparatorChar
    $comparison = if ($env:OS -eq "Windows_NT") {
        [StringComparison]::OrdinalIgnoreCase
    }
    else {
        [StringComparison]::Ordinal
    }

    $filesystemRoot = [IO.Path]::GetPathRoot($target).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
    if ($target.Equals($filesystemRoot, $comparison)) {
        throw "Refusing to remove a filesystem root: $target"
    }
    if ($target.Equals($allowed, $comparison)) {
        throw "Refusing to remove the allowed root itself: $target"
    }

    $allowedPrefix = $allowed + $separator
    if (-not $target.StartsWith($allowedPrefix, $comparison)) {
        throw "Removal target is outside the allowed root: $target"
    }

    $relative = $target.Substring($allowedPrefix.Length)
    $topLevel = $relative.Split(
        @([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar),
        [StringSplitOptions]::RemoveEmptyEntries
    )[0]
    if (-not $topLevel.StartsWith($TopLevelPrefix, $comparison)) {
        throw "Removal target is not inside a ${TopLevelPrefix}* directory: $target"
    }

    if (Test-Path -LiteralPath $target) {
        $resolved = (Resolve-Path -LiteralPath $target -ErrorAction Stop).ProviderPath.TrimEnd(
            [IO.Path]::DirectorySeparatorChar,
            [IO.Path]::AltDirectorySeparatorChar
        )
        if (-not $resolved.Equals($target, $comparison)) {
            throw "Removal target resolves to a different path: $target"
        }

        $current = Get-Item -LiteralPath $target -Force -ErrorAction Stop
        while (-not $current.FullName.Equals($allowed, $comparison)) {
            if (($current.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Removal target crosses a reparse point: $($current.FullName)"
            }
            $current = $current.Parent
            if ($null -eq $current) {
                throw "Removal target has no verified path back to the allowed root: $target"
            }
        }
    }

    return $target
}

function Remove-AwzSafeTree {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$AllowedRoot,

        [string]$TopLevelPrefix = "smoke-"
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "Refusing an empty filesystem path."
    }
    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $target = Assert-AwzSafeRemovalTarget -Path $Path -AllowedRoot $AllowedRoot -TopLevelPrefix $TopLevelPrefix
    Remove-Item -LiteralPath $target -Recurse -Force
}

Export-ModuleMember -Function Assert-AwzSafeRemovalTarget, Remove-AwzSafeTree
