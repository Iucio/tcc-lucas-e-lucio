BEGIN;

CREATE SCHEMA IF NOT EXISTS matinal_operacional;

-- ============================================================
-- ENUMS
-- ============================================================

CREATE TYPE matinal_operacional.perfil_usuario AS ENUM ('ADMIN', 'SUPERVISOR', 'OPERADOR', 'QUALIDADE', 'PCP');
CREATE TYPE matinal_operacional.status_op      AS ENUM ('PLANEJADA', 'EM_PRODUCAO', 'PAUSADA', 'FINALIZADA', 'CANCELADA');
CREATE TYPE matinal_operacional.status_pallet  AS ENUM ('EM_ESPERA', 'PARCIAL', 'FINALIZADO');
CREATE TYPE matinal_operacional.status_nf      AS ENUM ('PENDENTE', 'APROVADO', 'REPROVADO');


-- ============================================================
-- LEVEL 0 — no dependencies
-- ============================================================

CREATE TABLE matinal_operacional.usuario (
    id_usuario  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome        VARCHAR(120) NOT NULL,
    perfil      matinal_operacional.perfil_usuario NOT NULL,
    ativo       BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE matinal_operacional.galpao (
    id_galpao   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    codigo      VARCHAR(20)  NOT NULL UNIQUE,
    descricao   VARCHAR(200)
);

CREATE TABLE matinal_operacional.pj (
    id_pj         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    cnpj          VARCHAR(18)  NOT NULL UNIQUE,
    razao_social  VARCHAR(150) NOT NULL,
    nome_fantasia VARCHAR(100),
    telefone      VARCHAR(20),
    email         VARCHAR(100),
    status        VARCHAR(30)
);

CREATE TABLE matinal_operacional.endereco (
    id_endereco UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cidade      VARCHAR(100),
    estado      VARCHAR(50),
    pais        VARCHAR(50),
    UNIQUE (cidade, estado, pais)
);

CREATE TABLE matinal_operacional.produto_produzido (
    id_produto           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sku                  VARCHAR(40)  NOT NULL UNIQUE,
    nome                 VARCHAR(150) NOT NULL,
    ativo                BOOLEAN      NOT NULL DEFAULT TRUE,
    peso_sache_kg        NUMERIC(10,4),
    qtd_padrao_pallet    INTEGER,
    saches_por_fardo_cx  INTEGER,
    eh_instantaneo       BOOLEAN NOT NULL DEFAULT FALSE,
    eh_vitaminado        BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE matinal_operacional.nf (
    id_nfe        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nfe           VARCHAR(50) NOT NULL,
    nro_serie_nfe VARCHAR(4)  NOT NULL,
    data_emissao  DATE        NOT NULL,
    qtd_itens     INT,
    data_chegada  DATE,
    exp_chegada   DATE,
    status        matinal_operacional.status_nf NOT NULL DEFAULT 'PENDENTE',
    valor_total   NUMERIC(12,2),
    UNIQUE (nfe, nro_serie_nfe)
);

-- Merged: public.insumos + matinal_operacional.insumo
CREATE TABLE matinal_operacional.insumo (
    id_insumo        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome             VARCHAR(150) NOT NULL,
    descricao        TEXT,
    unidade          VARCHAR(20)  NOT NULL,
    qtd_padrao       NUMERIC(12,4),
    embalagem_padrao VARCHAR(80)
);


-- ============================================================
-- LEVEL 1
-- ============================================================

CREATE TABLE matinal_operacional.posicao_estoque (
    id_posicao UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_galpao  UUID NOT NULL REFERENCES matinal_operacional.galpao(id_galpao)
                   ON DELETE CASCADE ON UPDATE CASCADE,
    nro_bloco  VARCHAR(20) NOT NULL,
    andar      VARCHAR(10) NOT NULL,
    nro_rua    VARCHAR(20) NOT NULL,
    CONSTRAINT uq_posicao UNIQUE (id_galpao, nro_bloco, andar, nro_rua)
);

CREATE TABLE matinal_operacional.pj_endereco (
    id_pj       UUID NOT NULL,
    id_endereco UUID NOT NULL,
    complemento VARCHAR(200),
    PRIMARY KEY (id_pj, id_endereco),
    CONSTRAINT fk_pje_pj
        FOREIGN KEY (id_pj)       REFERENCES matinal_operacional.pj(id_pj)
            ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_pje_endereco
        FOREIGN KEY (id_endereco) REFERENCES matinal_operacional.endereco(id_endereco)
            ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE matinal_operacional.transportadora (
    id_transportadora UUID PRIMARY KEY,
    tel_contato       VARCHAR(11),
    CONSTRAINT fk_transportadora_pj
        FOREIGN KEY (id_transportadora) REFERENCES matinal_operacional.pj(id_pj)
            ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE matinal_operacional.fabricante (
    id_fabricante       UUID PRIMARY KEY,
    tecnico_responsavel VARCHAR(127),
    CONSTRAINT fk_fabricante_pj
        FOREIGN KEY (id_fabricante) REFERENCES matinal_operacional.pj(id_pj)
            ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE matinal_operacional.fornecedor (
    id_fornecedor        UUID PRIMARY KEY,
    vendedor_responsavel VARCHAR(127),
    CONSTRAINT fk_fornecedor_pj
        FOREIGN KEY (id_fornecedor) REFERENCES matinal_operacional.pj(id_pj)
            ON DELETE CASCADE ON UPDATE CASCADE
);


-- ============================================================
-- LEVEL 2
-- ============================================================

CREATE TABLE matinal_operacional.entrega (
    renavam           VARCHAR(11),
    id_nfe            UUID NOT NULL,
    id_transportadora UUID NOT NULL,
    cnh               VARCHAR(11),
    placa             VARCHAR(8),
    PRIMARY KEY (renavam, id_nfe, id_transportadora),
    CONSTRAINT fk_entrega_nf
        FOREIGN KEY (id_nfe) REFERENCES matinal_operacional.nf(id_nfe)
            ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_entrega_transportadora
        FOREIGN KEY (id_transportadora) REFERENCES matinal_operacional.transportadora(id_transportadora)
            ON DELETE CASCADE ON UPDATE CASCADE
);

-- Received-goods pallet (entrada); distinct from pallet_acabado (prod)
CREATE TABLE matinal_operacional.pallet (
    nro           UUID DEFAULT gen_random_uuid(),
    id_nfe        UUID NOT NULL,
    id_fornecedor UUID NOT NULL,
    alocado       BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (nro, id_nfe, id_fornecedor),
    CONSTRAINT fk_pallet_nf
        FOREIGN KEY (id_nfe) REFERENCES matinal_operacional.nf(id_nfe)
            ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_pallet_fornecedor
        FOREIGN KEY (id_fornecedor) REFERENCES matinal_operacional.fornecedor(id_fornecedor)
            ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE matinal_operacional.fornecedor_insumo (
    id_fornecedor UUID NOT NULL,
    id_insumo     UUID NOT NULL,
    data_inif     DATE NOT NULL,
    data_fim      DATE,
    PRIMARY KEY (id_fornecedor, id_insumo),
    CONSTRAINT fk_fi_fornecedor
        FOREIGN KEY (id_fornecedor) REFERENCES matinal_operacional.fornecedor(id_fornecedor)
            ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_fi_insumo
        FOREIGN KEY (id_insumo) REFERENCES matinal_operacional.insumo(id_insumo)
            ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE matinal_operacional.laudo (
    id_fabricante UUID    NOT NULL,
    nro_laudo     INTEGER NOT NULL,
    PRIMARY KEY (id_fabricante, nro_laudo),
    CONSTRAINT fk_laudo_fabricante
        FOREIGN KEY (id_fabricante) REFERENCES matinal_operacional.fabricante(id_fabricante)
            ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE matinal_operacional.ordem_producao (
    id_op                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_produto             UUID NOT NULL REFERENCES matinal_operacional.produto_produzido(id_produto)
                               ON DELETE CASCADE ON UPDATE CASCADE,
    id_usuario_responsavel UUID NOT NULL REFERENCES matinal_operacional.usuario(id_usuario)
                               ON DELETE CASCADE ON UPDATE CASCADE,
    status                 matinal_operacional.status_op NOT NULL DEFAULT 'PLANEJADA',
    total_kg               NUMERIC(14,3),
    data_fabricacao        DATE,
    data_validade          DATE,
    qtd_pcp                NUMERIC(14,3),
    observacoes            TEXT,
    inicio                 TIMESTAMP,
    fim                    TIMESTAMP,
    CONSTRAINT chk_op_periodo CHECK (fim IS NULL OR inicio IS NULL OR fim >= inicio)
);

-- Merged: public.item_nfe + matinal_operacional.item_nf
CREATE TABLE matinal_operacional.item_nf (
    linha             INTEGER NOT NULL,
    id_nfe            UUID    NOT NULL REFERENCES matinal_operacional.nf(id_nfe)
                          ON DELETE CASCADE ON UPDATE CASCADE,
    id_insumo         UUID    NOT NULL REFERENCES matinal_operacional.insumo(id_insumo)
                          ON DELETE CASCADE ON UPDATE CASCADE,
    qtd               NUMERIC(14,4) NOT NULL DEFAULT 0,
    valor_unitario    NUMERIC(14,4) NOT NULL DEFAULT 0,
    und_medida        VARCHAR(20),
    ncm_sh            VARCHAR(15),
    cst               VARCHAR(10),
    cfop              VARCHAR(10),
    aliquota_icms     NUMERIC(6,4),
    base_calculo_icms NUMERIC(14,4) DEFAULT 0,
    valor_icms        NUMERIC(14,4) DEFAULT 0,
    aliquota_ipi      NUMERIC(6,4),
    valor_total       NUMERIC(16,4) GENERATED ALWAYS AS (qtd * valor_unitario) STORED,
    PRIMARY KEY (linha, id_nfe, id_insumo)
);


-- ============================================================
-- LEVEL 3
-- ============================================================

CREATE TABLE matinal_operacional.avaria (
    nro_pallet    UUID        NOT NULL,
    id_nfe        UUID        NOT NULL,
    id_fornecedor UUID        NOT NULL,
    nro           UUID        DEFAULT gen_random_uuid(),
    qtd           INTEGER     NOT NULL,
    tipo          VARCHAR(50) NOT NULL,
    descricao     TEXT,
    PRIMARY KEY (nro_pallet, id_nfe, id_fornecedor, nro),
    CONSTRAINT fk_avaria_pallet
        FOREIGN KEY (nro_pallet, id_nfe, id_fornecedor)
            REFERENCES matinal_operacional.pallet(nro, id_nfe, id_fornecedor)
            ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE matinal_operacional.lote (
    id_fabricante   UUID        NOT NULL,
    nro_laudo       INTEGER     NOT NULL,
    nro_lote        UUID        DEFAULT gen_random_uuid(),
    sif             VARCHAR(20) NOT NULL,
    data_fabricacao DATE        NOT NULL,
    data_validade   DATE        NOT NULL,
    PRIMARY KEY (id_fabricante, nro_laudo, nro_lote),
    CONSTRAINT fk_lote_laudo
        FOREIGN KEY (id_fabricante, nro_laudo)
            REFERENCES matinal_operacional.laudo(id_fabricante, nro_laudo)
            ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE matinal_operacional.laudo_fornecedor (
    id_fornecedor UUID    NOT NULL,
    id_fabricante UUID    NOT NULL,
    nro_laudo     INTEGER NOT NULL,
    PRIMARY KEY (id_fornecedor, id_fabricante, nro_laudo),
    CONSTRAINT fk_fl_fornecedor
        FOREIGN KEY (id_fornecedor) REFERENCES matinal_operacional.fornecedor(id_fornecedor)
            ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_fl_laudo
        FOREIGN KEY (id_fabricante, nro_laudo)
            REFERENCES matinal_operacional.laudo(id_fabricante, nro_laudo)
            ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE matinal_operacional.execucao_ordem_producao_insumo (
    id_op          UUID NOT NULL REFERENCES matinal_operacional.ordem_producao(id_op)
                       ON DELETE CASCADE ON UPDATE CASCADE,
    id_insumo      UUID NOT NULL REFERENCES matinal_operacional.insumo(id_insumo)
                       ON DELETE CASCADE ON UPDATE CASCADE,
    qtd_consumidas NUMERIC(14,4) NOT NULL DEFAULT 0,
    qtd_perdidas   NUMERIC(14,4) NOT NULL DEFAULT 0,
    PRIMARY KEY (id_op, id_insumo)
);

CREATE TABLE matinal_operacional.execucao_ordem_producao_item_nfe (
    id_op          UUID    NOT NULL REFERENCES matinal_operacional.ordem_producao(id_op)
                       ON DELETE CASCADE ON UPDATE CASCADE,
    linha_item_nf  INTEGER NOT NULL,
    id_nfe_item    UUID    NOT NULL,
    id_insumo_item UUID    NOT NULL,
    qtd_consumidos NUMERIC(14,4) NOT NULL DEFAULT 0,
    qtd_perdidas   NUMERIC(14,4) NOT NULL DEFAULT 0,
    PRIMARY KEY (id_op, linha_item_nf, id_nfe_item, id_insumo_item),
    CONSTRAINT fk_exec_item_nf
        FOREIGN KEY (linha_item_nf, id_nfe_item, id_insumo_item)
            REFERENCES matinal_operacional.item_nf(linha, id_nfe, id_insumo)
            ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE matinal_operacional.sessao (
    id_sessao               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_op                   UUID NOT NULL REFERENCES matinal_operacional.ordem_producao(id_op)
                                ON DELETE CASCADE ON UPDATE CASCADE,
    id_usuario_operador     UUID NOT NULL REFERENCES matinal_operacional.usuario(id_usuario)
                                ON DELETE CASCADE ON UPDATE CASCADE,
    hora_programada_inicio  TIMESTAMP,
    hora_programada_fim     TIMESTAMP,
    hora_real_inicio        TIMESTAMP,
    hora_real_fim           TIMESTAMP,
    motivo_atraso           VARCHAR(200),
    atraso_minutos          INTEGER,
    total_saches_produzidos INTEGER NOT NULL DEFAULT 0,
    total_perdas_varredura  INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE matinal_operacional.item_lote (
    linha         INTEGER NOT NULL,
    id_nfe        UUID    NOT NULL,
    id_insumo     UUID    NOT NULL,
    id_fabricante UUID    NOT NULL,
    nro_laudo     INTEGER NOT NULL,
    nro_lote      UUID    NOT NULL,
    PRIMARY KEY (linha, id_nfe, id_insumo, id_fabricante, nro_laudo, nro_lote),
    CONSTRAINT fk_inl_item_nf
        FOREIGN KEY (linha, id_nfe, id_insumo)
            REFERENCES matinal_operacional.item_nf(linha, id_nfe, id_insumo)
            ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_inl_lote
        FOREIGN KEY (id_fabricante, nro_laudo, nro_lote)
            REFERENCES matinal_operacional.lote(id_fabricante, nro_laudo, nro_lote)
            ON DELETE CASCADE ON UPDATE CASCADE
);


-- ============================================================
-- LEVEL 4
-- ============================================================

CREATE TABLE matinal_operacional.parada (
    id_sessao         UUID    NOT NULL REFERENCES matinal_operacional.sessao(id_sessao)
                          ON DELETE CASCADE ON UPDATE CASCADE,
    nro_parada        INTEGER NOT NULL,
    ppm               NUMERIC(10,2),
    tipo              VARCHAR(50),
    dt_hr_inicio      TIMESTAMP,
    dt_hr_fim         TIMESTAMP,
    saches_acumulados INTEGER,
    status            VARCHAR(30),
    categoria         VARCHAR(50),
    PRIMARY KEY (id_sessao, nro_parada)
);

-- Finished-product pallet (prod); distinct from received-goods pallet (entrada)
CREATE TABLE matinal_operacional.pallet_acabado (
    id_pallet              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_sessao              UUID NOT NULL REFERENCES matinal_operacional.sessao(id_sessao)
                               ON DELETE CASCADE ON UPDATE CASCADE,
    id_posicao_estoque     UUID REFERENCES matinal_operacional.posicao_estoque(id_posicao)
                               ON DELETE CASCADE ON UPDATE CASCADE,
    id_usuario_paletizador UUID REFERENCES matinal_operacional.usuario(id_usuario)
                               ON DELETE CASCADE ON UPDATE CASCADE,
    etiqueta_qr            VARCHAR(80) UNIQUE,
    status                 matinal_operacional.status_pallet NOT NULL DEFAULT 'EM_ESPERA',
    total_kg               NUMERIC(14,3) NOT NULL DEFAULT 0,
    qtd_items              INTEGER       NOT NULL DEFAULT 0,
    data_hora_inicio       TIMESTAMP,
    data_hora_fim          TIMESTAMP,
    data_hr_conf           TIMESTAMP,
    data_inspecao          TIMESTAMP,
    total_kg_parcial       NUMERIC(14,3) NOT NULL DEFAULT 0
);


-- ============================================================
-- LEVEL 5
-- ============================================================

CREATE TABLE matinal_operacional.pallet_parcial_acabado (
    id_pallet          UUID    NOT NULL REFERENCES matinal_operacional.pallet_acabado(id_pallet)
                           ON DELETE CASCADE ON UPDATE CASCADE,
    nro                INTEGER NOT NULL,
    total_kg           NUMERIC(14,3) NOT NULL DEFAULT 0,
    data_inspecao      TIMESTAMP,
    qtd_fardos_parcial INTEGER      NOT NULL DEFAULT 0,
    PRIMARY KEY (id_pallet, nro)
);

CREATE TABLE matinal_operacional.pallet_final_encartuchado (
    id_pallet_encartuchado UUID NOT NULL REFERENCES matinal_operacional.pallet_acabado(id_pallet)
                               ON DELETE CASCADE ON UPDATE CASCADE,
    id_usuario_responsavel UUID NOT NULL REFERENCES matinal_operacional.usuario(id_usuario)
                               ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (id_pallet_encartuchado)
);

CREATE TABLE matinal_operacional.pallet_origem_encartuchado (
    id_pallet_encartuchado UUID NOT NULL REFERENCES matinal_operacional.pallet_acabado(id_pallet)
                               ON DELETE CASCADE ON UPDATE CASCADE,
    id_pallet_origem       UUID NOT NULL REFERENCES matinal_operacional.pallet_acabado(id_pallet)
                               ON DELETE CASCADE ON UPDATE CASCADE,
    PRIMARY KEY (id_pallet_encartuchado, id_pallet_origem)
);


-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX idx_op_status     ON matinal_operacional.ordem_producao  USING HASH (status);
CREATE INDEX idx_op_produto    ON matinal_operacional.ordem_producao  USING HASH (id_produto);
CREATE INDEX idx_sessao_op     ON matinal_operacional.sessao(id_op);
CREATE INDEX idx_pallet_sessao ON matinal_operacional.pallet_acabado(id_sessao);


-- ============================================================
-- VIEW
-- ============================================================

CREATE OR REPLACE VIEW matinal_operacional.vw_ordens_em_producao_tempo AS
SELECT
    op.id_op,
    op.status,
    pp.sku,
    pp.nome                                        AS produto,
    u.nome                                         AS responsavel,
    op.inicio,
    op.fim,
    op.data_fabricacao,
    op.data_validade,
    (op.fim IS NULL AND op.inicio IS NOT NULL)     AS em_producao,
    (COALESCE(op.fim, now()) - op.inicio)          AS tempo_producao,
    ROUND(
        EXTRACT(EPOCH FROM (COALESCE(op.fim, now()) - op.inicio)) / 3600.0,
        2
    )                                              AS horas_em_producao
FROM matinal_operacional.ordem_producao op
JOIN matinal_operacional.produto_produzido pp ON pp.id_produto = op.id_produto
JOIN matinal_operacional.usuario u             ON u.id_usuario  = op.id_usuario_responsavel
WHERE op.status = 'EM_PRODUCAO'
   OR (op.inicio IS NOT NULL AND op.fim IS NULL)
ORDER BY op.inicio ASC;

COMMENT ON VIEW matinal_operacional.vw_ordens_em_producao_tempo IS
    'Ordens de produção atualmente em andamento, com tempo decorrido desde o início.';


