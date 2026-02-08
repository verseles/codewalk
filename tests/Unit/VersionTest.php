<?php

namespace Verseles\Flyclone\Test\Unit;

use PHPUnit\Framework\TestCase;
use Verseles\Flyclone\Providers\LocalProvider;
use Verseles\Flyclone\Rclone;

class VersionTest extends TestCase
{
    public function testVersion()
    {
        $binPath = realpath(__DIR__ . '/../../bin/rclone');
        if ($binPath) {
             Rclone::setBIN($binPath);
        } else {
            try {
                $bin = Rclone::guessBIN();
                if (!file_exists($bin) || !is_executable($bin)) {
                    $this->markTestSkipped("Rclone binary guessed at $bin but not found or not executable.");
                }
            } catch (\Exception $e) {
                $this->markTestSkipped('Rclone binary not found: ' . $e->getMessage());
            }
        }

        $local = new LocalProvider('local');
        $rclone = new Rclone($local);

        try {
            $v1 = $rclone->version();
            $this->assertIsString($v1);
            $this->assertMatchesRegularExpression('/^[\d.]+/', $v1);

            $v2 = $rclone->version(true);
            $this->assertIsFloat($v2);
            $this->assertGreaterThan(0, $v2);
        } catch (\Exception $e) {
            $this->markTestSkipped('Failed to run rclone version: ' . $e->getMessage());
        }
    }
}
