<?php

declare(strict_types=1);

namespace Verseles\Flyclone\Test\Unit;

use PHPUnit\Framework\Attributes\Test;
use PHPUnit\Framework\TestCase;
use RuntimeException;
use Symfony\Component\Process\ExecutableFinder;
use Verseles\Flyclone\ProcessManager;

class ProcessManagerTest extends TestCase
{
    protected function tearDown(): void
    {
        ProcessManager::setExecutableFinder(null);
        ProcessManager::setBin('');
    }

    #[Test]
    public function guess_bin_returns_path_when_found(): void
    {
        $mockFinder = $this->createMock(ExecutableFinder::class);
        $mockFinder->method('find')
            ->willReturn('/usr/bin/rclone');

        ProcessManager::setExecutableFinder($mockFinder);

        $bin = ProcessManager::guessBin();

        self::assertEquals('/usr/bin/rclone', $bin);
    }

    #[Test]
    public function guess_bin_throws_exception_when_rclone_not_found(): void
    {
        $mockFinder = $this->createMock(ExecutableFinder::class);
        $mockFinder->method('find')
            ->willReturn(null);

        ProcessManager::setExecutableFinder($mockFinder);

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('Rclone binary not found');

        ProcessManager::guessBin();
    }
}
