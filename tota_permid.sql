-- ============================================================================
-- PARA SERVIDORES ESX (usa la tabla 'users')
-- Descomenta y ejecuta esta sección si usas ESX.
-- ============================================================================
ALTER TABLE `users`
ADD COLUMN `permid` INT(11) NULL DEFAULT NULL,
ADD COLUMN `discord` VARCHAR(50) NULL DEFAULT NULL;


-- ============================================================================
-- PARA SERVIDORES QBCORE (usa la tabla 'players')
-- Descomenta y ejecuta esta sección si usas QBCore.
-- ============================================================================
ALTER TABLE `players`
ADD COLUMN `permid` INT(11) NULL DEFAULT NULL,
ADD COLUMN `discord` VARCHAR(50) NULL DEFAULT NULL;