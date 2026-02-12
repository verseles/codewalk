<?php

declare(strict_types=1);

namespace Verseles\Flyclone\Test\Unit;

use PHPUnit\Framework\TestCase;
use RuntimeException;
use Symfony\Component\Process\Process;
use Verseles\Flyclone\Exception\SyntaxErrorException;
use Verseles\Flyclone\ProcessManager;
use Verseles\Flyclone\Providers\LocalProvider;
use Verseles\Flyclone\Rclone;

class CheckCommandTest extends TestCase
{
    public function testCheckReturnsFalseOnDifference(): void
    {
        $local = new LocalProvider('test');
        $rclone = new Rclone($local);

        $mockPm = $this->createMock(ProcessManager::class);
        $rclone->setProcessManager($mockPm);

        $previous = new RuntimeException("Process failed");
        $syntaxError = new SyntaxErrorException($previous, "2 matching files\n1 differences found", 1);

        $mockPm->method('run')->willThrowException($syntaxError);

        $result = $rclone->check('/source', '/dest');

        $this->assertFalse($result, 'check() should return false when differences are found');
    }

    public function testCheckThrowsOnActualSyntaxError(): void
    {
        $local = new LocalProvider('test');
        $rclone = new Rclone($local);

        $mockPm = $this->createMock(ProcessManager::class);
        $rclone->setProcessManager($mockPm);

        $previous = new RuntimeException("Process failed");
        $syntaxError = new SyntaxErrorException($previous, "Error: unknown flag: --invalid", 1);

        $mockPm->method('run')->willThrowException($syntaxError);

        $this->expectException(SyntaxErrorException::class);
        $this->expectExceptionMessage("Error: unknown flag: --invalid");

        $rclone->check('/source', '/dest');
    }

    public function testCheckReturnsTrueOnSuccess(): void
    {
        $local = new LocalProvider('test');
        $rclone = new Rclone($local);

        $mockPm = $this->createMock(ProcessManager::class);
        $rclone->setProcessManager($mockPm);

        // Mock success process
        $process = $this->createMock(Process::class);
        $process->method('getOutput')->willReturn('');

        $mockPm->method('run')->willReturn($process);

        $result = $rclone->check('/source', '/dest');

        $this->assertTrue($result, 'check() should return true when no differences found');
    }
}
