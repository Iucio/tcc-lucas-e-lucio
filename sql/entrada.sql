CREATE SCHEMA matinal_operacional;


CREATE TYPE matinal_operacional.status_nf AS ENUM ('PENDENTE', 'APROVADO', 'REPROVADO');

CREATE TABLE matinal_operacional.pj (
    id_pj         SERIAL        PRIMARY KEY,
    cnpj          VARCHAR(18)   NOT NULL UNIQUE,
    razao_social  VARCHAR(150)  NOT NULL,
    nome_fantasia VARCHAR(100),
    telefone      VARCHAR(20),
    email         VARCHAR(100),
    status        VARCHAR(30)
);


CREATE TABLE matinal_operacional.endereco (
    id_endereco  SERIAL        PRIMARY KEY,
    cidade       VARCHAR(100),
    estado       VARCHAR(50),
    pais         VARCHAR(50),
    UNIQUE (cidade, estado, pais)
);


CREATE TABLE matinal_operacional.pj_endereco (
    id_pj        INT  NOT NULL,
    id_endereco  INT  NOT NULL,
    complemento  VARCHAR(200),
    PRIMARY KEY (id_pj, id_endereco),
    CONSTRAINT fk_pje_pj
        FOREIGN KEY (id_pj) REFERENCES matinal_operacional.pj(id_pj)
                ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_pje_endereco
        FOREIGN KEY (id_endereco) REFERENCES matinal_operacional.endereco(id_endereco)
                ON DELETE CASCADE
        ON UPDATE CASCADE
);


CREATE TABLE matinal_operacional.transportadora (
    id_transportadora  INT  PRIMARY KEY,
    tel_contato  VARCHAR (11),
    CONSTRAINT fk_transportadora_pj
        FOREIGN KEY (id_transportadora) REFERENCES matinal_operacional.pj(id_pj)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE TABLE matinal_operacional.fabricante (
    id_fabricante INT  PRIMARY KEY,
    tecnico_responsavel VARCHAR(127),
    CONSTRAINT fk_fabricante_pj
        FOREIGN KEY (id_fabricante) REFERENCES matinal_operacional.pj(id_pj)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);


CREATE TABLE matinal_operacional.fornecedor (
    id_fornecedor  INT  PRIMARY KEY,
    vendedor_responsavel VARCHAR(127),
    CONSTRAINT fk_fornecedor_pj
        FOREIGN KEY (id_fornecedor) REFERENCES matinal_operacional.pj(id_pj)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);


CREATE TABLE matinal_operacional.nf (
    id_nfe         SERIAL PRIMARY KEY,
    nfe            VARCHAR(50) NOT NULL,
    nro_serie_nfe  VARCHAR(4) NOT NULL,
    data_emissao  DATE          NOT NULL,
    qtd_itens     INT,
    data_chegada  DATE,
    exp_chegada   DATE,
    status        matinal_operacional.status_nf     NOT NULL DEFAULT 'PENDENTE',
    valor_total   NUMERIC(12,2),
    UNIQUE (nfe, nro_serie_nfe)
);


CREATE TABLE matinal_operacional.entrega (
    renavam             VARCHAR(11),
    id_nfe               INT NOT NULL,
    id_transportadora   INT NOT NULL,
    cnh                 VARCHAR(11),
    placa               VARCHAR(8),
    PRIMARY KEY (renavam, id_nfe, id_transportadora),
    CONSTRAINT fk_entrega_nf
        FOREIGN KEY (id_nfe) REFERENCES matinal_operacional.nf(id_nfe)
                ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_entrega_transportadora
        FOREIGN KEY (id_transportadora) REFERENCES matinal_operacional.transportadora(id_transportadora)
                ON DELETE CASCADE
        ON UPDATE CASCADE
);


CREATE TABLE matinal_operacional.pallet (
    nro            SERIAL,
    id_nfe         INT  NOT NULL,
    id_fornecedor  INT          NOT NULL,
    alocado        BOOLEAN      DEFAULT FALSE,
    PRIMARY KEY (nro, id_nfe, id_fornecedor),
    CONSTRAINT fk_pallet_nf
        FOREIGN KEY (id_nfe) REFERENCES matinal_operacional.nf(id_nfe)
                ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_pallet_fornecedor
        FOREIGN KEY (id_fornecedor) REFERENCES matinal_operacional.fornecedor(id_fornecedor)
                ON DELETE CASCADE
        ON UPDATE CASCADE
);


CREATE TABLE matinal_operacional.avaria (
    nro_pallet  INT          NOT NULL,
    id_nfe         INT  NOT NULL,
    id_fornecedor  INT          NOT NULL,
    nro         SERIAL,
    qtd         INT NOT NULL,
    tipo        VARCHAR(50) NOT NULL,
    descricao   TEXT,
    PRIMARY KEY (nro_pallet, id_nfe, id_fornecedor, nro),
    CONSTRAINT fk_avaria_pallet
        FOREIGN KEY (nro, id_nfe, id_fornecedor) REFERENCES matinal_operacional.pallet(nro, id_nfe, id_fornecedor)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);


CREATE TABLE matinal_operacional.insumo (
    id_insumo     SERIAL        PRIMARY KEY,  -- surrogate
    nome        VARCHAR(100)  NOT NULL,
    descricao   TEXT,
    unidade     VARCHAR(20) NOT NULL,
    qtd_padrao  NUMERIC(10,3),
    emb_padrao  VARCHAR(50)
);


CREATE TABLE matinal_operacional.fornecedor_insumo (
    id_fornecedor  INT   NOT NULL,
    id_insumo      INT   NOT NULL,
    data_inif      DATE NOT NULL,
    data_fim       DATE,
    PRIMARY KEY (id_fornecedor, id_insumo),
    CONSTRAINT fk_fi_fornecedor
        FOREIGN KEY (id_fornecedor) REFERENCES matinal_operacional.fornecedor(id_fornecedor)
                ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_fi_insumo
        FOREIGN KEY (id_insumo) REFERENCES matinal_operacional.insumo(id_insumo)
                ON DELETE CASCADE
        ON UPDATE CASCADE
);



CREATE TABLE matinal_operacional.laudo (
    id_fabricante  INT  NOT NULL,
    nro_laudo      INT  NOT NULL,
    PRIMARY KEY (id_fabricante, nro_laudo),
    CONSTRAINT fk_laudo_fabricante
        FOREIGN KEY (id_fabricante) REFERENCES matinal_operacional.fabricante(id_fabricante)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);


CREATE TABLE matinal_operacional.lote (
    id_fabricante   INT          NOT NULL,
    nro_laudo       INT          NOT NULL,
    nro_lote         SERIAL,
    sif             VARCHAR(20) NOT NULL,
    data_fabricacao DATE NOT NULL,
    data_validade   DATE NOT NULL,
    PRIMARY KEY (id_fabricante, nro_laudo, nro_lote),
    CONSTRAINT fk_lote_laudo
        FOREIGN KEY (id_fabricante, nro_laudo)
            REFERENCES matinal_operacional.laudo(id_fabricante, nro_laudo)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);


CREATE TABLE matinal_operacional.item_nf (
    linha              SERIAL,
    id_nfe             INT NOT NULL,
    id_insumo          INT NOT NULL,
    qtd                NUMERIC(10,3) NOT NULL,
    valor_unitario     NUMERIC(12,2) NOT NULL,
    valor_total        NUMERIC(12,2)
                           GENERATED ALWAYS AS (qtd * valor_unitario) STORED,
    und_medida         VARCHAR(20),
    NCM_SH             VARCHAR(10),
    O_CST              VARCHAR(5),
    CFOP               VARCHAR(5),
    aliquota_icms      NUMERIC(5,2),
    base_calculo_icms  NUMERIC(12,2),
    valor_icms         NUMERIC(12,2),
    aliquota_ipi       NUMERIC(5,2),
    PRIMARY KEY (linha, id_nfe, id_insumo),
    CONSTRAINT fk_itnf_nf
        FOREIGN KEY (id_nfe) REFERENCES matinal_operacional.nf(id_nfe)
                ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_itnf_insumo
        FOREIGN KEY (id_insumo) REFERENCES matinal_operacional.insumo(id_insumo)
                ON DELETE CASCADE
        ON UPDATE CASCADE
);



CREATE TABLE matinal_operacional.item_lote (
    linha              SERIAL,
    id_nfe             INT NOT NULL,
    id_insumo          INT NOT NULL,
    id_fabricante  INT  NOT NULL,
    nro_laudo      INT  NOT NULL,
    nro_lote        INT  NOT NULL,
    PRIMARY KEY (linha, id_nfe, id_insumo, id_fabricante, nro_laudo, nro_lote),
    CONSTRAINT fk_inl_item_nf
        FOREIGN KEY (linha, id_nfe, id_insumo) REFERENCES matinal_operacional.item_nf(linha, id_nfe, id_insumo)
                ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_inl_lote
        FOREIGN KEY (id_fabricante, nro_laudo, nro_lote)
            REFERENCES matinal_operacional.lote(id_fabricante, nro_laudo, nro_lote)
                    ON DELETE CASCADE
        ON UPDATE CASCADE
);


CREATE TABLE matinal_operacional.laudo_fornecedor (
    id_fornecedor  INT  NOT NULL,
    id_fabricante  INT  NOT NULL,
    nro_laudo      INT  NOT NULL,
    PRIMARY KEY (id_fornecedor, id_fabricante, nro_laudo),
    CONSTRAINT fk_fl_fornecedor
        FOREIGN KEY (id_fornecedor) REFERENCES matinal_operacional.fornecedor(id_fornecedor)
                ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_fl_laudo
        FOREIGN KEY (id_fabricante, nro_laudo)
            REFERENCES matinal_operacional.laudo(id_fabricante, nro_laudo)
                    ON DELETE CASCADE
        ON UPDATE CASCADE
);





INSERT INTO pj (cnpj, razao_social, nome_fantasia, telefone, email, status) VALUES
  ('12.345.678/0001-90', 'Transportes Rápidos Ltda',    'TransRápido',  '(21)99999-0001', 'contato@transrapido.com',  'ativo'),
  ('23.456.789/0001-01', 'Logística Norte S/A',          'LogNorte',     '(21)99999-0002', 'contato@lognorte.com',     'ativo'),
  ('34.567.890/0001-12', 'Frigorífico Central Ltda',     'FrigoCentral', '(11)99999-0003', 'contato@frigocentral.com', 'ativo'),
  ('45.678.901/0001-23', 'Indústria Sul de Carnes S/A',  'SulCarnes',    '(51)99999-0004', 'contato@sulcarnes.com',    'ativo'),
  ('56.789.012/0001-34', 'Distribuidora Alfa Ltda',      'Alfa Carnes',  '(21)99999-0005', 'contato@alfa.com',         'ativo'),
  ('67.890.123/0001-45', 'Comercial Beta S/A',           'Beta Frios',   '(21)99999-0006', 'contato@beta.com',         'ativo');

INSERT INTO transportadora (id_surr) VALUES (1), (2);
INSERT INTO fabricante     (id_surr) VALUES (3), (4);
INSERT INTO fornecedor     (id_surr) VALUES (5), (6);

INSERT INTO endereco (cidade, estado, pais, complemento) VALUES
  ('Rio de Janeiro', 'RJ', 'Brasil', 'Av. Brasil, 1500'),
  ('São Paulo',      'SP', 'Brasil', 'Rua das Indústrias, 200'),
  ('Porto Alegre',   'RS', 'Brasil', 'Av. Ipiranga, 800');

INSERT INTO pj_endereco (id_pj, id_endereco) VALUES
  (1, 1), (3, 2), (4, 3), (5, 1), (6, 1);

INSERT INTO nf (pk_nf, nfe, item, data_emissao, qtd_itens, data_chegada, exp_chegada, status, valor_total) VALUES
  ('NF-001', '35240112345678000195550010000001011234567890', 'Lote frigorífico', '2024-03-01', 3, '2024-03-05', '2024-03-04', 'aprovado',  15000.00),
  ('NF-002', '35240212345678000195550010000002021234567891', 'Insumos secos',    '2024-03-10', 2, '2024-03-15', '2024-03-14', 'pendente',   8500.00);

INSERT INTO entrega (renavam, pk_nf, id_transportadora, cnh, placa) VALUES
  ('00123456789', 'NF-001', 1, '04567890123', 'ABC-1234'),
  ('00987654321', 'NF-002', 2, '09876543210', 'XYZ-5678');

INSERT INTO pallet (pk_nf, id_fornecedor, alocado) VALUES
  ('NF-001', 5, TRUE),
  ('NF-001', 6, FALSE),
  ('NF-002', 5, TRUE);

INSERT INTO avaria (nro_pallet, qtd, tipo, descricao) VALUES
  (1, 2, 'Embalagem danificada', 'Caixas amassadas no canto inferior'),
  (1, 1, 'Produto vencido',      'Validade expirada em 1 item'),
  (3, 1, 'Temperatura',          'Quebra de cadeia do frio detectada');

INSERT INTO insumo (nome, descricao, unidade, qtd_padrao, emb_padrao) VALUES
  ('Carne Bovina Dianteiro', 'Corte dianteiro resfriado', 'kg', 25.000, 'Caixa 25kg'),
  ('Frango Inteiro',         'Frango resfriado inteiro',  'kg', 12.000, 'Caixa 12kg'),
  ('Linguiça Toscana',       'Linguiça suína temperada',  'kg',  5.000, 'Bandeja 5kg');

INSERT INTO fornecedor_insumo (id_fornecedor, id_insumo, data_inif, data_fim) VALUES
  (5, 1, '2023-01-01', NULL),
  (5, 2, '2023-01-01', NULL),
  (6, 2, '2023-06-01', NULL),
  (6, 3, '2023-06-01', '2024-01-31');


INSERT INTO item_nf (pk_nf, id_insumo, qtd, valor_unitario, und_medida, NCM_SH, O_CST, CFOP, aliquota_icms, base_calculo_icms, valor_icms, aliquota_ipi) VALUES
  ('NF-001', 1,  50.000, 28.50, 'kg', '0201.20.00', '0-060', '1101', 12.00,  1425.00, 171.00, 0.00),
  ('NF-001', 2, 120.000, 12.80, 'kg', '0207.11.00', '0-060', '1101', 12.00,  1536.00, 184.32, 0.00),
  ('NF-002', 3,  80.000, 22.00, 'kg', '1601.00.00', '0-060', '1101',  7.00,  1760.00, 123.20, 0.00);

INSERT INTO laudo (id_fabricante, nro_laudo) VALUES
  (3, 1), (3, 2), (4, 1);

INSERT INTO lote (id_fabricante, nro_laudo, sif, data_fabricacao, data_validade) VALUES
  (3, 1, 'SIF-1234', '2024-02-20', '2024-04-20'),
  (3, 1, 'SIF-1234', '2024-02-22', '2024-04-22'),
  (3, 2, 'SIF-5678', '2024-03-01', '2024-05-01'),
  (4, 1, 'SIF-9999', '2024-02-28', '2024-04-28');

INSERT INTO item_nf_lote (linha, id_fabricante, nro_laudo, id_lote) VALUES
  (1, 3, 1, 1), (1, 3, 1, 2),
  (2, 3, 2, 3),
  (3, 4, 1, 4);

INSERT INTO fornecedor_laudo (id_fornecedor, id_fabricante, nro_laudo) VALUES
  (5, 3, 1), (5, 3, 2), (6, 4, 1);


-- ============================================================
-- DADOS DAS NOTAS FISCAIS REAIS
-- NF1: HECKE REPRESENTACOES COMERCIAIS LTDA (20/05/2026)
-- NF2: BARBOSA & MARQUES - NF 924.476 (18/03/2026)
-- NF3: BARBOSA & MARQUES - NF 924.473 (18/03/2026)
-- ============================================================

DO $$
DECLARE
  v_hecke    INT;  v_barbosa  INT;
  v_jwmf     INT;  v_tiocarlo INT;
  v_end_hecke INT; v_end_barbosa INT;
  v_end_jwmf  INT; v_end_tiocarlo INT;
  v_emb_banana INT;    v_emb_baunilha INT;
  v_emb_chocolate INT; v_emb_morango INT;
  v_cx_diet INT;       v_dosador INT;
  v_mix_vit INT;       v_shake_baunilha INT;
  v_shake_choco INT;   v_shake_morango INT;
  v_shake_banana INT;
  v_leite_uht INT;     v_leite_po INT;
BEGIN

  INSERT INTO pj (cnpj, razao_social, telefone, status)
    VALUES ('05.094.612/0008-80', 'HECKE REPRESENTACOES COMERCIAIS LTDA', '(41) 3273-1120', 'ativo')
    RETURNING id_surr INTO v_hecke;
  INSERT INTO fornecedor (id_surr) VALUES (v_hecke);

  INSERT INTO pj (cnpj, razao_social, nome_fantasia, telefone, status)
    VALUES ('19.273.747/0001-41', 'BARBOSA & MARQUES - MATRIZ', 'B&M', '(33) 3277-9111', 'ativo')
    RETURNING id_surr INTO v_barbosa;
  INSERT INTO fornecedor (id_surr) VALUES (v_barbosa);

  INSERT INTO pj (cnpj, razao_social, status)
    VALUES ('23.918.066/0001-60', 'JWMF TRANSPORTES E LOGISTICA LTDA', 'ativo')
    RETURNING id_surr INTO v_jwmf;
  INSERT INTO transportadora (id_surr) VALUES (v_jwmf);

  INSERT INTO pj (cnpj, razao_social, nome_fantasia, status)
    VALUES ('90.147.539/0001-60', 'TIO CARLO TRANSPOR E COMERCIO', 'TIO CARLO', 'ativo')
    RETURNING id_surr INTO v_tiocarlo;
  INSERT INTO transportadora (id_surr) VALUES (v_tiocarlo);

  INSERT INTO endereco (cidade, estado, pais, complemento)
    VALUES ('Curitiba', 'PR', 'Brasil', 'Rua Ella Ferdinanda Dorotheia Paasche, 120 - Butiatuvinha - CEP 82315-490')
    RETURNING id_endereco INTO v_end_hecke;
  INSERT INTO pj_endereco VALUES (v_hecke, v_end_hecke);

  INSERT INTO endereco (cidade, estado, pais, complemento)
    VALUES ('Governador Valadares', 'MG', 'Brasil', 'R. Aluísio Esteves, 250 - Lourdes - CEP 35032-010')
    RETURNING id_endereco INTO v_end_barbosa;
  INSERT INTO pj_endereco VALUES (v_barbosa, v_end_barbosa);

  INSERT INTO endereco (cidade, estado, pais, complemento)
    VALUES ('Curitiba', 'PR', 'Brasil', 'R. Theodoro Locker, 821 - B. Cidade Industrial')
    RETURNING id_endereco INTO v_end_jwmf;
  INSERT INTO pj_endereco VALUES (v_jwmf, v_end_jwmf);

  INSERT INTO endereco (cidade, estado, pais, complemento)
    VALUES ('São Marcos', 'RS', 'Brasil', 'Rua Mons. Henrique Compagnoni, 340')
    RETURNING id_endereco INTO v_end_tiocarlo;
  INSERT INTO pj_endereco VALUES (v_tiocarlo, v_end_tiocarlo);

  INSERT INTO insumo (nome, descricao, unidade, emb_padrao)
    VALUES ('EMBALAGEM DIET SHAKE BANANA 420G', 'Cód. fornecedor: 000293 | CEST: 2806400', 'UN', 'Unidade')
    RETURNING id_surr INTO v_emb_banana;
  INSERT INTO insumo (nome, descricao, unidade, emb_padrao)
    VALUES ('EMBALAGEM DIET SHAKE BAUNILHA 420G', 'Cód. fornecedor: 000294 | CEST: 2806400', 'UN', 'Unidade')
    RETURNING id_surr INTO v_emb_baunilha;
  INSERT INTO insumo (nome, descricao, unidade, emb_padrao)
    VALUES ('EMBALAGEM DIET SHAKE CHOCOLATE 420G', 'Cód. fornecedor: 000292 | CEST: 2806400', 'UN', 'Unidade')
    RETURNING id_surr INTO v_emb_chocolate;
  INSERT INTO insumo (nome, descricao, unidade, emb_padrao)
    VALUES ('EMBALAGEM DIET SHAKE MORANGO 420G', 'Cód. fornecedor: 000291 | CEST: 2806400', 'UN', 'Unidade')
    RETURNING id_surr INTO v_emb_morango;
  INSERT INTO insumo (nome, descricao, unidade, emb_padrao)
    VALUES ('CAIXA PAP. EMB. 6X420G - DIET SHAKE', 'Cód. fornecedor: 000270', 'UN', 'Unidade')
    RETURNING id_surr INTO v_cx_diet;
  INSERT INTO insumo (nome, descricao, unidade, emb_padrao)
    VALUES ('DOSADOR 60ML HASTE CURTA DIET SHAKE', 'Cód. fornecedor: 002162', 'UN', 'Unidade')
    RETURNING id_surr INTO v_dosador;
  INSERT INTO insumo (nome, descricao, unidade, qtd_padrao, emb_padrao)
    VALUES ('MIX VITAMINICO LH', 'Cód. fornecedor: 001080 | CEST: 1300600', 'KG', 20.000, 'Caixa 20kg')
    RETURNING id_surr INTO v_mix_vit;
  INSERT INTO insumo (nome, descricao, unidade, qtd_padrao, emb_padrao)
    VALUES ('DIET SHAKE BAUNILHA', 'Cód. fornecedor: 000067', 'KG', 25.000, 'Saco 25kg')
    RETURNING id_surr INTO v_shake_baunilha;
  INSERT INTO insumo (nome, descricao, unidade, qtd_padrao, emb_padrao)
    VALUES ('DIET SHAKE CHOCOLATE', 'Cód. fornecedor: 000237', 'KG', 25.000, 'Saco 25kg')
    RETURNING id_surr INTO v_shake_choco;
  INSERT INTO insumo (nome, descricao, unidade, qtd_padrao, emb_padrao)
    VALUES ('DIET SHAKE MORANGO', 'Cód. fornecedor: 000238', 'KG', 25.000, 'Saco 25kg')
    RETURNING id_surr INTO v_shake_morango;
  INSERT INTO insumo (nome, descricao, unidade, qtd_padrao, emb_padrao)
    VALUES ('DIET SHAKE BANANA', 'Cód. fornecedor: 000066', 'KG', 25.000, 'Saco 25kg')
    RETURNING id_surr INTO v_shake_banana;

  INSERT INTO insumo (nome, descricao, unidade, qtd_padrao, emb_padrao)
    VALUES ('LEITE UHT DE CABRA INTEGRAL', 'Cód. fornecedor: 1166001 | CEST: 1701600', 'CX12', 12.000, 'Caixa 12 unidades')
    RETURNING id_surr INTO v_leite_uht;
  INSERT INTO insumo (nome, descricao, unidade, qtd_padrao, emb_padrao)
    VALUES ('LEITE DE CABRA EM PO CAPRILAT INTEGRAL', 'Cód. fornecedor: 1997001 | CEST: 1701200', 'KG', 25.000, 'Frasco 25kg')
    RETURNING id_surr INTO v_leite_po;

  INSERT INTO fornecedor_insumo (id_fornecedor, id_insumo, data_inif) VALUES
    (v_hecke, v_emb_banana,     '2026-05-20'),
    (v_hecke, v_emb_baunilha,   '2026-05-20'),
    (v_hecke, v_emb_chocolate,  '2026-05-20'),
    (v_hecke, v_emb_morango,    '2026-05-20'),
    (v_hecke, v_cx_diet,        '2026-05-20'),
    (v_hecke, v_dosador,        '2026-05-20'),
    (v_hecke, v_mix_vit,        '2026-05-20'),
    (v_hecke, v_shake_baunilha, '2026-05-20'),
    (v_hecke, v_shake_choco,    '2026-05-20'),
    (v_hecke, v_shake_morango,  '2026-05-20'),
    (v_hecke, v_shake_banana,   '2026-05-20'),
    (v_barbosa, v_leite_uht,    '2026-03-18'),
    (v_barbosa, v_leite_po,     '2026-03-18');

  INSERT INTO nf (pk_nf, nfe, item, data_emissao, qtd_itens, data_chegada, status, valor_total) VALUES
    ('41260505094612000880550010000026931320981555', 'NF 000.002.693 / Série 1',
     'VENDA DE MERC ADQ OU RECEB DE TERCEIROS', '2026-05-20', 11, '2026-05-20', 'pendente', 149899.48),
    ('31260319273747000141551010009244761629599198', 'NF 000.924.476 / Série 101',
     'VENDA DE PRODUCAO', '2026-03-18', 1, '2026-03-23', 'pendente', 121594.80),
    ('31260319273747000141551010009244731705904225', 'NF 000.924.473 / Série 101',
     'VENDA DE PRODUCAO', '2026-03-18', 1, '2026-03-23', 'pendente', 520000.00);

  INSERT INTO pallet (pk_nf, id_fornecedor, alocado) VALUES
    ('41260505094612000880550010000026931320981555', v_hecke,   TRUE),
    ('31260319273747000141551010009244761629599198', v_barbosa, TRUE),
    ('31260319273747000141551010009244731705904225', v_barbosa, TRUE);

  INSERT INTO item_nf (pk_nf, id_insumo, qtd, valor_unitario, und_medida, NCM_SH, O_CST, CFOP, aliquota_icms, base_calculo_icms, valor_icms, aliquota_ipi) VALUES
    ('41260505094612000880550010000026931320981555', v_emb_banana,     5000,  1.58, 'UN', '49119900', '000', '6102', 12.00,  7900.00,   948.00, 0.00),
    ('41260505094612000880550010000026931320981555', v_emb_baunilha,   7000,  1.58, 'UN', '49119900', '000', '6102', 12.00, 11060.00,  1327.20, 0.00),
    ('41260505094612000880550010000026931320981555', v_emb_chocolate,  8000,  1.58, 'UN', '49119900', '000', '6102', 12.00, 12640.00,  1516.80, 0.00),
    ('41260505094612000880550010000026931320981555', v_emb_morango,    7000,  1.58, 'UN', '49119900', '000', '6102', 12.00, 11060.00,  1327.20, 0.00),
    ('41260505094612000880550010000026931320981555', v_cx_diet,        1436,  2.16, 'UN', '48191000', '000', '6102', 12.00,  3101.76,   372.21, 0.00),
    ('41260505094612000880550010000026931320981555', v_dosador,       10000,  0.66, 'UN', '39239090', '000', '6102', 12.00,  6600.00,   792.00, 0.00),
    ('41260505094612000880550010000026931320981555', v_mix_vit,          160, 63.70, 'KG', '29362911', '000', '6102', 12.00, 10192.00,  1223.04, 0.00),
    ('41260505094612000880550010000026931320981555', v_shake_baunilha, 1260, 19.67, 'KG', '21069030', '000', '6102', 12.00, 24784.20,  2974.10, 0.00),
    ('41260505094612000880550010000026931320981555', v_shake_choco,    1260, 19.76, 'KG', '21069030', '000', '6102', 12.00, 24897.60,  2987.71, 0.00),
    ('41260505094612000880550010000026931320981555', v_shake_morango,  1260, 19.05, 'KG', '21069030', '000', '6102', 12.00, 24003.00,  2880.36, 0.00),
    ('41260505094612000880550010000026931320981555', v_shake_banana,    756, 18.07, 'KG', '21069030', '000', '6102', 12.00, 13660.92,  1639.31, 0.00);

  INSERT INTO item_nf (pk_nf, id_insumo, qtd, valor_unitario, und_medida, NCM_SH, O_CST, CFOP, aliquota_icms, base_calculo_icms, valor_icms, aliquota_ipi) VALUES
    ('31260319273747000141551010009244761629599198', v_leite_uht, 947, 128.40, 'CX12', '04012010', '040', '6101', 0, 0, 0, 0);

  INSERT INTO item_nf (pk_nf, id_insumo, qtd, valor_unitario, und_medida, NCM_SH, O_CST, CFOP, aliquota_icms, base_calculo_icms, valor_icms, aliquota_ipi) VALUES
    ('31260319273747000141551010009244731705904225', v_leite_po, 10000, 52.00, 'KG', '04022110', '040', '6101', 0, 0, 0, 0);


END $$;
