<?php

declare(strict_types=1);

namespace Verseles\Flyclone\Tests\Unit;

use PHPUnit\Framework\TestCase;
use RuntimeException;
use Symfony\Component\Process\ExecutableFinder;
use Verseles\Flyclone\ProcessManager;

class ProcessManagerTest extends TestCase
{
    protected function tearDown(): void
    {
        // Reset static state
        ProcessManager::setBin('');
        ProcessManager::setExecutableFinder(null);
        parent::tearDown();
    }

    public function testGuessBinThrowsExceptionWhenRcloneNotFound(): void
    {
        $mockFinder = $this->createMock(ExecutableFinder::class);
        $mockFinder->expects($this->once())
            ->method('find')
            ->with('rclone', null, $this->anything())
            ->willReturn(null);

        ProcessManager::setExecutableFinder($mockFinder);

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('Rclone binary not found');

        ProcessManager::guessBin();
    }

    public function testGuessBinReturnsPathWhenFound(): void
    {
        $mockFinder = $this->createMock(ExecutableFinder::class);
        $mockFinder->expects($this->once())
            ->method('find')
            ->with('rclone', null, $this->anything())
            ->willReturn('/usr/bin/rclone');

        ProcessManager::setExecutableFinder($mockFinder);

        $bin = ProcessManager::guessBin();

        $this->assertSame('/usr/bin/rclone', $bin);
    }
}
