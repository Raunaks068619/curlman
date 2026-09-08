import path from 'node:path';
import type { ForgeConfig } from '@electron-forge/shared-types';
import { MakerDeb } from '@electron-forge/maker-deb';
import { MakerRpm } from '@electron-forge/maker-rpm';
import { MakerSquirrel } from '@electron-forge/maker-squirrel';
import { MakerZIP } from '@electron-forge/maker-zip';
import { VitePlugin } from '@electron-forge/plugin-vite';

const config: ForgeConfig = {
  packagerConfig: {
    appBundleId: 'com.raunak.Curlman.Electron',
    executableName: process.platform === 'linux' ? 'curlman' : 'Curlman',
    icon: 'Brand/Curlman-Icon',
    name: 'Curlman',
    extraResource: [
      'node_modules/sql.js/dist/sql-wasm.wasm',
      'Brand/Curlman-Icon.png',
      'Brand/Curlman-TrayTemplate.png',
      'Brand/Curlman-TrayTemplate@2x.png',
    ],
  },
  makers: [
    new MakerSquirrel({
      name: 'curlman',
      authors: 'Raunak Singh',
      description: 'Fast, local-first API testing built around cURL',
      setupIcon: path.resolve('Brand/Curlman-Icon.ico'),
    }),
    new MakerZIP({}, ['darwin', 'win32', 'linux']),
    new MakerRpm({
      options: {
        name: 'curlman',
        productName: 'Curlman',
        genericName: 'API Client',
        description: 'Fast, local-first API testing built around cURL',
        productDescription: 'Paste, edit, execute, and revisit HTTP API requests without a large API workspace.',
        license: 'MIT',
        group: 'Development/Tools',
        homepage: 'https://github.com/Raunaks068619/curlman',
        icon: path.resolve('Brand/Curlman-Icon.png'),
        categories: ['Development', 'Network'],
      },
    }),
    new MakerDeb({
      options: {
        name: 'curlman',
        productName: 'Curlman',
        genericName: 'API Client',
        description: 'Fast, local-first API testing built around cURL',
        productDescription: 'Paste, edit, execute, and revisit HTTP API requests without a large API workspace.',
        section: 'devel',
        priority: 'optional',
        maintainer: 'Raunak Singh',
        homepage: 'https://github.com/Raunaks068619/curlman',
        icon: path.resolve('Brand/Curlman-Icon.png'),
        categories: ['Development', 'Network'],
      },
    }),
  ],
  plugins: [
    new VitePlugin({
      build: [
        {
          entry: 'apps/electron/src/main/main.ts',
          config: 'vite.main.config.mts',
          target: 'main',
        },
        {
          entry: 'apps/electron/src/preload/preload.ts',
          config: 'vite.preload.config.mts',
          target: 'preload',
        },
      ],
      renderer: [
        {
          name: 'main_window',
          config: 'vite.renderer.config.mts',
        },
      ],
    }),
  ],
};

export default config;
