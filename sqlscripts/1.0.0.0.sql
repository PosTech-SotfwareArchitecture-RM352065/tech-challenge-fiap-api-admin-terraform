IF(OBJECT_ID('CustomerRequests') IS NOT NULL) DROP TABLE CustomerRequests
IF(OBJECT_ID('Orders') IS NOT NULL) DROP TABLE Orders
IF(OBJECT_ID('Products') IS NOT NULL) DROP TABLE Products

CREATE TABLE CustomerRequests (    
    Id              UNIQUEIDENTIFIER    NOT NULL
,   CustomerId      UNIQUEIDENTIFIER    NOT NULL
,   RequestedAt     DATETIME            NOT NULL
,   [Type]          VARCHAR(15)         NOT NULL
,   [Status]        VARCHAR(15)         NOT NULL
,   [Comments]      VARCHAR(200)        NULL
,   CONSTRAINT Pk_CustomerRequests PRIMARY KEY NONCLUSTERED (Id)
)
GO

CREATE TABLE Orders (
    Id          UNIQUEIDENTIFIER    NOT NULL
,   Code        INT                 NOT NULL
,   [Status]    INT                 NOT NULL
,   TotalAmount DECIMAL(18, 2)      NOT NULL
,   PaymentId   UNIQUEIDENTIFIER    NOT NULL
,   PayedAt     DATETIME            NOT NULL
,   AcceptedAt  DATETIME            NULL
,   FinalizedAt DATETIME            NULL
,   CONSTRAINT Pk_Orders PRIMARY KEY NONCLUSTERED (Id)
)

CREATE TABLE Products (
    Id           UNIQUEIDENTIFIER   NOT NULL
,   Name         VARCHAR(20)        NOT NULL
,   Description  VARCHAR(50)        NOT NULL
,   Category     VARCHAR(10)        NOT NULL
,   UnitPrice    DECIMAL(18, 2)     NOT NULL
,   IsEnabled    BIT                NOT NULL DEFAULT(1)
,   CONSTRAINT Pk_Products PRIMARY KEY NONCLUSTERED (Id)
,   CONSTRAINT Uk1_Products UNIQUE (Name)
)
