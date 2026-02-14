<?php

declare(strict_types=1);

namespace Verseles\Flyclone\Providers;

class GDriveProvider extends Provider
{
    protected string $provider = 'drive';

    /**
     * @param array<string, mixed> $flags
     */
    public function __construct(string $name, array $flags = [])
    {
        parent::__construct($this->provider, $name, $flags);
    }
}
