package etl

import (
	"crypto/sha1"
	"database/sql"
	"encoding/hex"
	"fmt"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/navapbc/its-log/internal/storage"
	"github.com/navapbc/its-log/internal/types"
	"go.uber.org/zap"
)

// FIXME: These need to be at the ETL level, not the type level.
type RunEtlParams struct {
	AppId   string
	GinCtx  *gin.Context
	EtlName string
	KeyId   string
	Storage *storage.Storage
	Payload map[string]any
}

type StandardErrorResponseParams struct {
	c      *gin.Context
	err    error
	etlP   *RunEtlParams
	Status int
	Method string
	Date   types.ILTime
	Name   string
}
type GetETLRow struct {
	Name    string
	Kind    string
	Body    sql.NullString
	LastRun sql.NullInt64
}

func NewStandardErrorResponse(etlP *RunEtlParams, err error) *StandardErrorResponseParams {
	return &StandardErrorResponseParams{
		c:    etlP.GinCtx,
		err:  err,
		etlP: etlP,
	}
}

func (ser *StandardErrorResponseParams) SetStatus(status int) *StandardErrorResponseParams {
	ser.Status = status
	return ser
}

func (ser *StandardErrorResponseParams) Send(msg string) {
	zap.L().Error("ERR",
		zap.Int("status", ser.Status),
		zap.String("msg", msg),
		zap.String("error", ser.err.Error()),
		zap.String("name", ser.etlP.EtlName),
		zap.String("date", ser.etlP.Storage.YYYYMMDD()),
	)
	ser.c.JSON(ser.Status, gin.H{
		"status":  "error",
		"method":  ser.c.Request.Method,
		"message": fmt.Sprintf("%s: %s", msg, ser.err.Error()),
		"date":    ser.etlP.Storage.YYYYMMDD(),
		"name":    ser.etlP.EtlName,
	})
}

type StandardOkResponseParams struct {
	c      *gin.Context
	etlP   *RunEtlParams
	Status int
}

func NewStandardOkResponse(c *gin.Context, etlP *RunEtlParams) *StandardOkResponseParams {
	return &StandardOkResponseParams{
		c:    c,
		etlP: etlP,
	}
}

func (sok *StandardOkResponseParams) SetStatus(status int) *StandardOkResponseParams {
	sok.Status = status
	return sok
}

func (sok *StandardOkResponseParams) Send() {
	name := sok.etlP.EtlName
	date := sok.etlP.Storage.ILTime.AsYYYYMMDD()

	zap.L().Info("OK",
		zap.Int("status", sok.Status),
		zap.String("name", name),
		zap.String("date", date),
	)

	sok.c.JSON(sok.Status, gin.H{
		"status": "ok",
		"method": sok.c.Request.Method,
		"date":   date,
		"name":   name,
	})
}

// ID        int64
// LastRun   time.Time
// Date      int64
// KeyID     string
// Operation string
// Tags      sql.NullString
// Value     sql.NullString
// Count     float64

type ItslogEtl struct {
	ID       int64
	Inserted int64
	LastRun  sql.NullInt64
	KeyID    string
	Name     string
	Kind     string
	Body     sql.NullString
}

type ItslogEvent struct {
	ID        int64
	Timestamp sql.NullInt64
	KeyID     string
	Cluster   sql.NullString
	Tags      string
	Value     sql.NullString
}

type ItslogSummary struct {
	ID        int64
	LastRun   int64
	Date      string
	KeyID     string
	Operation string
	Tags      string
	Value     string
	Count     float64
	Hash      sql.NullString
}

func (ils *ItslogSummary) ReturnHash() string {
	fields := []string{
		ils.Date,
		ils.KeyID,
		ils.Operation,
		ils.Tags,
		ils.Value,
		strconv.FormatFloat(ils.Count, 'f', 3, 64),
	}
	joined := strings.Join(fields, "-")
	h := sha1.New()
	h.Write([]byte(joined))
	hashed := hex.EncodeToString(h.Sum(nil))
	return hashed
}

func (ils *ItslogSummary) UpdateHash() {
	hashed := ils.ReturnHash()
	ils.Hash = sql.NullString{String: hashed, Valid: true}
}

func (ils ItslogSummary) IsHashSameAs(other ItslogSummary) bool {
	return ils.ReturnHash() == other.ReturnHash()
}

type InsertSummaryParams struct {
	KeyID     string
	Date      string
	Operation string
	Tags      string
	Value     string
	Count     float64
	Hash      sql.NullString
}
