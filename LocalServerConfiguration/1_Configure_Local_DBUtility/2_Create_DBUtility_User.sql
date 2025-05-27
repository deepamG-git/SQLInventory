/*
.SYNOPSIS
    DBUtility Database Default Database User and Loin Creation Script
.DESCRIPTION
   Creates a Login SQLInventoryUser
   Creates a Database User SQLInventoryUser
   Assignes db_owner database role to SQLInventoryUser
.NOTES
    Author: Deepam Ghosh
    Version: 1.0
*/


-- === User Configurable Section ===
DECLARE @LoginName SYSNAME = 'SQLInventoryUser';
DECLARE @LoginPassword NVARCHAR(128) = 'DBAUser@1234';
DECLARE @DefaultDB SYSNAME = 'master';
DECLARE @DatabaseName SYSNAME = 'DBUtility';
DECLARE @DBRole SYSNAME = 'db_owner';
-- ================================

-- Step 1: Create login if not exists
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = @LoginName)
BEGIN
    DECLARE @CreateLoginSQL NVARCHAR(MAX) = '
    CREATE LOGIN [' + @LoginName + '] 
    WITH PASSWORD = N''' + @LoginPassword + ''',
         DEFAULT_DATABASE = [' + @DefaultDB + '], 
         CHECK_POLICY = OFF, 
         CHECK_EXPIRATION = OFF;
    ';
    EXEC (@CreateLoginSQL);
    PRINT 'Login [' + @LoginName + '] created successfully.';
END
ELSE
BEGIN
    PRINT 'Login [' + @LoginName + '] already exists.';
END

-- Step 2: Create user in DB
DECLARE @CreateUserSQL NVARCHAR(MAX) = '
USE [' + @DatabaseName + '];

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = ''' + @LoginName + ''')
BEGIN
    CREATE USER [' + @LoginName + '] FOR LOGIN [' + @LoginName + '];
    PRINT ''User [' + @LoginName + '] created in database [' + @DatabaseName + '].'';
END
ELSE
BEGIN
    PRINT ''User [' + @LoginName + '] already exists in database [' + @DatabaseName + '].'';
END

-- Step 3: Add user to db_owner
ALTER ROLE [' + @DBRole + '] ADD MEMBER [' + @LoginName + '];
PRINT ''User [' + @LoginName + '] added to role [' + @DBRole + '].'';
';

EXEC (@CreateUserSQL);
