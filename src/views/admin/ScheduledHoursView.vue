<template>
  <div class="scheduled-hours-view">
    <div class="page-header">
      <div>
        <h1 class="page-title">Horarios programados</h1>
        <p class="page-desc">Programa cambios futuros sin modificar el horario semanal por defecto</p>
      </div>
      <button class="btn btn-primary" @click="handleCreateClick">+ Nueva programación</button>
    </div>

    <div class="form-group" style="max-width: 300px; margin-bottom: 20px;">
      <label class="label">Peluquero</label>
      <div class="select-field select-barber">
        <select class="input" v-model="selectedBarberId" @change="loadPrograms">
          <option value="">Seleccionar peluquero...</option>
          <option v-for="b in barbers" :key="b.id" :value="b.id">{{ b.name }}</option>
        </select>
      </div>
    </div>

    <div v-if="!selectedBarberId" class="empty-card card">
      <p>Selecciona un peluquero para gestionar su planificación.</p>
    </div>

    <div v-else-if="loading" class="skeleton-list">
      <div class="skeleton" style="height: 72px" v-for="i in 4" :key="i"></div>
    </div>

    <div v-else>
      <div v-if="programs.length === 0" class="empty-card card">
        <p>No hay horarios programados para este peluquero.</p>
      </div>

      <div v-else class="program-list">
        <article v-for="program in programs" :key="program.id" class="program-item card">
          <div>
            <div class="program-head">
              <strong>{{ formatRange(program.start_date, program.end_date) }}</strong>
              <span class="badge" :class="statusClass(getStatus(program))">{{ getStatusLabel(getStatus(program)) }}</span>
            </div>
            <p class="program-days">{{ summarizeWorkingDays(program.schedule_program_hours || []) }}</p>
            <p v-if="program.notes" class="program-note">{{ program.notes }}</p>
          </div>

          <div class="program-actions">
            <button class="btn btn-secondary btn-sm" @click="openEditModal(program)">Editar</button>
            <button
              class="btn btn-ghost btn-sm"
              style="color: var(--danger);"
              @click="cancelProgram(program)"
            >
              Cancelar
            </button>
          </div>
        </article>
      </div>
    </div>

    <div v-if="showModal" class="modal-overlay" @click.self="closeModal">
      <div class="modal-content modal-large">
        <div class="modal-top">
          <h3 class="modal-title">{{ editingProgramId ? 'Editar programación' : 'Nueva programación' }}</h3>
          <p class="modal-subtitle">Define un periodo y los horarios que se aplicarán automáticamente a las reservas de esas fechas.</p>
        </div>

        <section class="modal-section">
          <div class="section-title-row">
            <h4 class="section-title">Periodo</h4>
          </div>

          <div class="form-row">
            <div class="form-group">
              <label class="label">Fecha de inicio</label>
              <div class="date-field">
                <input
                  class="input date-input"
                  type="date"
                  v-model="form.start_date"
                  :min="todayDate"
                  @change="enforceStartDate"
                  @blur="enforceStartDate"
                />
              </div>
            </div>
            <div class="form-group">
              <label class="label">Fecha de finalización (opcional)</label>
              <div class="date-field">
                <input
                  class="input date-input"
                  type="date"
                  v-model="form.end_date"
                  :min="endDateMin"
                  @change="enforceEndDate"
                  @blur="enforceEndDate"
                />
              </div>
              <small v-if="form.start_date" class="date-help">Desde {{ formatDate(form.start_date) }} en adelante</small>
            </div>
          </div>

          <div class="form-group notes-field">
            <label class="label">Notas (opcional)</label>
            <input class="input" v-model="form.notes" placeholder="Ej.: horario especial de enero" />
          </div>
        </section>

        <section class="modal-section">
          <div class="section-title-row">
            <h4 class="section-title">Configuración semanal</h4>
            <span class="section-help">Incluye turnos partidos y días cerrados</span>
          </div>
          <p v-if="disableInactiveDays" class="range-impact-note">
            En este rango solo se aplican: <strong>{{ affectedDaysLabel }}</strong>.
            Los demás días quedan bloqueados porque no se usan en estas fechas.
          </p>
          <WeeklyHoursEditor
            v-model="form.hours"
            :days="days"
            :active-day-indexes="affectedDayIndexes"
            :disable-inactive-days="disableInactiveDays"
          />
        </section>

        <div v-if="conflictWarnings.length > 0" class="warning-box">
          <strong>Advertencia: hay citas confirmadas/completadas fuera del nuevo horario.</strong>
          <p>No se modificarán automáticamente. Revisa estas citas antes de guardar:</p>
          <ul class="warning-list">
            <li v-for="item in conflictWarnings.slice(0, 8)" :key="item.id">
              {{ formatDateTime(item.start_time) }} - {{ item.customers?.name || 'Cliente' }}
            </li>
          </ul>
          <p v-if="conflictWarnings.length > 8">...y {{ conflictWarnings.length - 8 }} más.</p>
          <button class="btn btn-secondary btn-sm warning-cta" @click="viewAffectedAppointments">
            Ver {{ conflictWarnings.length }} cita(s) afectada(s) en calendario
          </button>
        </div>

        <div class="modal-actions">
          <button class="btn btn-secondary" @click="closeModal">Cancelar</button>
          <button class="btn btn-primary" @click="saveProgram">
            {{ editingProgramId ? 'Guardar cambios' : 'Crear programación' }}
          </button>
        </div>
      </div>
    </div>

    <div v-if="showSelectBarberModal" class="modal-overlay" @click.self="showSelectBarberModal = false">
      <div class="modal-content barber-warning-modal">
        <h3 class="modal-title">Selecciona un peluquero</h3>
        <p class="modal-subtitle">Antes de crear una programación debes elegir un peluquero en el desplegable superior.</p>
        <div class="modal-actions" style="margin-top: 16px;">
          <button class="btn btn-primary" @click="showSelectBarberModal = false">Entendido</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { barbersService } from '../../services/barbersService'
import { scheduleService } from '../../services/scheduleService'
import { useToast } from '../../composables/useToast'
import { lockBodyScroll, unlockBodyScroll } from '../../composables/useBodyScrollLock'
import WeeklyHoursEditor from '../../components/admin/WeeklyHoursEditor.vue'

export default {
  name: 'ScheduledHoursView',
  components: { WeeklyHoursEditor },
  data() {
    return {
      barbers: [],
      selectedBarberId: '',
      loading: false,
      programs: [],
      showModal: false,
      showSelectBarberModal: false,
      editingProgramId: null,
      conflictWarnings: [],
      days: scheduleService.DEFAULT_DAYS,
      form: {
        start_date: '',
        end_date: '',
        notes: '',
        hours: scheduleService.createDefaultHours()
      }
    }
  },
  async mounted() {
    try {
      this.barbers = await barbersService.getAll()
    } catch (error) {
      useToast().error('No se pudieron cargar los peluqueros')
    }
  },
  beforeUnmount() {
    // Safety net: ensure body scroll is never left locked if the view is destroyed mid-modal
    if (this.showModal || this.showSelectBarberModal) {
      unlockBodyScroll()
    }
  },
  computed: {
    todayDate() {
      const today = new Date()
      return `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`
    },
    endDateMin() {
      return this.form.start_date || ''
    },
    affectedDayIndexes() {
      if (!this.form.start_date || !this.form.end_date) return [0, 1, 2, 3, 4, 5, 6]
      if (this.form.end_date < this.form.start_date) return []

      const start = new Date(this.form.start_date + 'T12:00:00')
      const end = new Date(this.form.end_date + 'T12:00:00')
      const included = new Set()

      const cursor = new Date(start)
      let safeGuard = 0
      while (cursor <= end && safeGuard < 400) {
        let day = cursor.getDay() - 1
        if (day < 0) day = 6
        included.add(day)
        cursor.setDate(cursor.getDate() + 1)
        safeGuard += 1
      }

      return Array.from(included).sort((a, b) => a - b)
    },
    disableInactiveDays() {
      return Boolean(
        this.form.start_date
        && this.form.end_date
        && this.affectedDayIndexes.length > 0
        && this.affectedDayIndexes.length < 7
      )
    },
    affectedDaysLabel() {
      if (this.affectedDayIndexes.length === 7) return 'todos los días'
      return this.affectedDayIndexes.map(idx => this.days[idx]).join(', ')
    }
  },
  watch: {
    showModal(isOpen) {
      if (isOpen) lockBodyScroll()
      else unlockBodyScroll()
    },
    showSelectBarberModal(isOpen) {
      if (isOpen) lockBodyScroll()
      else unlockBodyScroll()
    },
    'form.start_date'(newStart) {
      this.enforceStartDate()
      if (this.form.end_date && newStart && this.form.end_date < newStart) {
        this.form.end_date = newStart
      }
    },
    'form.end_date'() {
      this.enforceEndDate()
    }
  },
  methods: {
    enforceStartDate() {
      if (!this.form.start_date) return

      if (this.form.start_date < this.todayDate) {
        this.form.start_date = this.todayDate
      }

      if (this.form.end_date && this.form.end_date < this.form.start_date) {
        this.form.end_date = this.form.start_date
      }
    },
    enforceEndDate() {
      if (!this.form.end_date) return

      const minEndDate = this.form.start_date || this.todayDate
      if (this.form.end_date < minEndDate) {
        this.form.end_date = minEndDate
      }
    },
    handleCreateClick() {
      if (!this.selectedBarberId) {
        this.showSelectBarberModal = true
        return
      }
      this.openCreateModal()
    },
    async loadPrograms() {
      if (!this.selectedBarberId) {
        this.programs = []
        return
      }

      this.loading = true
      try {
        this.programs = await scheduleService.getSchedulePrograms(this.selectedBarberId)
      } catch (error) {
        useToast().error('No se pudieron cargar los horarios programados')
      }
      this.loading = false
    },

    openCreateModal() {
      this.editingProgramId = null
      this.conflictWarnings = []
      this.form = {
        start_date: '',
        end_date: '',
        notes: '',
        hours: scheduleService.createDefaultHours()
      }
      this.showModal = true
    },

    openEditModal(program) {
      this.editingProgramId = program.id
      this.conflictWarnings = []
      this.form = {
        start_date: program.start_date,
        end_date: program.end_date || '',
        notes: program.notes || '',
        hours: scheduleService.normalizeHours(program.schedule_program_hours || [])
      }
      this.showModal = true
    },

    closeModal() {
      this.showModal = false
      this.editingProgramId = null
      this.conflictWarnings = []
    },

    async validateAndCollectWarnings() {
      if (!this.form.start_date) {
        useToast().error('La fecha de inicio es obligatoria')
        return false
      }
      if (this.form.start_date < this.todayDate) {
        useToast().error('La fecha de inicio no puede ser anterior a hoy')
        return false
      }
      if (this.form.end_date && this.form.end_date < this.form.start_date) {
        useToast().error('La fecha final no puede ser anterior a la inicial')
        return false
      }

      const hoursError = scheduleService.validateHours(this.form.hours)
      if (hoursError) {
        useToast().error(hoursError)
        return false
      }

      try {
        const overlaps = await scheduleService.getConflictingPrograms(
          this.selectedBarberId,
          this.form.start_date,
          this.form.end_date || null,
          this.editingProgramId
        )
        if (overlaps.length > 0) {
          useToast().error('Ese periodo se solapa con otra programación activa')
          return false
        }

        this.conflictWarnings = await scheduleService.getAppointmentsAffectedByProgram(
          this.selectedBarberId,
          this.form.start_date,
          this.form.end_date || null,
          this.form.hours
        )
      } catch (error) {
        useToast().error('No se pudieron validar conflictos')
        return false
      }

      if (this.conflictWarnings.length > 0) {
        const shouldContinue = window.confirm(
          `Se han detectado ${this.conflictWarnings.length} cita(s) fuera del nuevo horario. ¿Quieres guardar igualmente?`
        )
        if (!shouldContinue) return false
      }

      return true
    },

    async saveProgram() {
      if (!this.selectedBarberId) {
        useToast().error('Selecciona un peluquero')
        return
      }

      const isValid = await this.validateAndCollectWarnings()
      if (!isValid) return

      const payload = {
        barber_id: this.selectedBarberId,
        start_date: this.form.start_date,
        end_date: this.form.end_date || null,
        notes: this.form.notes,
        hours: this.form.hours
      }

      try {
        if (this.editingProgramId) {
          await scheduleService.updateScheduleProgram(this.editingProgramId, payload)
          useToast().success('Programación actualizada')
        } else {
          await scheduleService.createScheduleProgram(payload)
          useToast().success('Programación creada')
        }
        this.closeModal()
        await this.loadPrograms()
      } catch (error) {
        const message = String(error?.message || '')
        if (message.includes('SCHEDULE_PERIOD_OVERLAP')) {
          useToast().error('El periodo se solapa con otra programación')
          return
        }
        if (message.includes('PROGRAM_END_BEFORE_START')) {
          useToast().error('La fecha de fin debe ser posterior o igual a la de inicio')
          return
        }
        useToast().error('No se pudo guardar la programación')
      }
    },

    viewAffectedAppointments() {
      if (this.conflictWarnings.length === 0) return

      const ids = this.conflictWarnings.map(item => item.id).filter(Boolean)
      if (ids.length === 0) return

      sessionStorage.setItem('affected_appointments_ids', JSON.stringify(ids))
      sessionStorage.setItem('affected_appointments_context', JSON.stringify({
        barberId: this.selectedBarberId,
        startDate: this.form.start_date,
        endDate: this.form.end_date || null
      }))

      this.$router.push({
        name: 'AdminCalendar',
        query: {
          affected: '1',
          start: this.form.start_date || ''
        }
      })
    },

    async cancelProgram(program) {
      const ok = window.confirm('¿Eliminar esta programación? No se eliminarán citas existentes.')
      if (!ok) return

      try {
        await scheduleService.cancelScheduleProgram(program.id)
        useToast().success('Programación eliminada')
        await this.loadPrograms()
      } catch (error) {
        useToast().error('No se pudo eliminar la programación')
      }
    },

    getStatus(program) {
      const today = new Date()
      const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`

      if (program.start_date > todayStr) return 'scheduled'
      if (program.end_date && program.end_date < todayStr) return 'finished'
      return 'active'
    },

    getStatusLabel(status) {
      const labels = {
        scheduled: 'Programado',
        active: 'Vigente',
        finished: 'Finalizado'
      }
      return labels[status] || status
    },

    statusClass(status) {
      const classes = {
        scheduled: 'badge-info',
        active: 'badge-success',
        finished: 'badge-warning'
      }
      return classes[status] || 'badge-info'
    },

    summarizeWorkingDays(hours) {
      const active = (hours || []).filter(h => h.is_working)
      if (active.length === 0) return 'Todos los días cerrados'
      if (active.length === 7) return 'Abierto todos los días'
      return active
        .sort((a, b) => a.day_of_week - b.day_of_week)
        .map(h => this.days[h.day_of_week])
        .join(', ')
    },

    formatRange(startDate, endDate) {
      const start = this.formatDate(startDate)
      if (!endDate) return `${start} - sin fecha final`
      return `${start} - ${this.formatDate(endDate)}`
    },

    formatDate(dateStr) {
      if (!dateStr) return ''
      return new Date(dateStr + 'T12:00:00').toLocaleDateString('es-ES', {
        day: 'numeric',
        month: 'short',
        year: 'numeric'
      })
    },

    formatDateTime(datetime) {
      return new Date(datetime).toLocaleString('es-ES', {
        day: 'numeric',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      })
    }
  }
}
</script>

<style scoped>
.page-header { display: flex; align-items: flex-start; justify-content: space-between; margin-bottom: 24px; gap: 16px; flex-wrap: wrap; }
.page-title { font-size: 28px; font-weight: 800; margin-bottom: 4px; }
.page-desc { color: var(--text-secondary); font-size: 15px; }

.skeleton-list { display: flex; flex-direction: column; gap: 10px; }
.empty-card { text-align: center; color: var(--text-secondary); }

.program-list { display: flex; flex-direction: column; gap: 10px; }
.program-item { display: flex; align-items: center; justify-content: space-between; gap: 16px; padding: 16px 20px; }
.program-head { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
.program-days { color: var(--text-secondary); font-size: 13px; margin-top: 4px; }
.program-note { color: var(--text-tertiary); font-size: 13px; margin-top: 6px; font-style: italic; }
.program-actions { display: flex; gap: 8px; flex-wrap: wrap; }

.form-row { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 12px; }
.form-row .form-group { margin-bottom: 0; }

.date-field {
  position: relative;
}

.date-field::before {
  content: '📅';
  position: absolute;
  left: 12px;
  top: 50%;
  transform: translateY(-50%);
  font-size: 13px;
  opacity: 0.8;
  pointer-events: none;
}

.date-input {
  padding-left: 34px;
  background-image: linear-gradient(180deg, rgba(255, 255, 255, 0.03), rgba(255, 255, 255, 0));
  border-color: var(--border-light);
}

.date-input:hover {
  border-color: rgba(99, 102, 241, 0.45);
}

.date-help {
  display: block;
  margin-top: 6px;
  font-size: 11px;
  color: var(--text-tertiary);
}

.date-field :deep(input[type="date"]::-webkit-calendar-picker-indicator) {
  cursor: pointer;
  opacity: 0.85;
  filter: invert(0.85);
}

.date-field :deep(input[type="date"]::-webkit-calendar-picker-indicator:hover) {
  opacity: 1;
}
.modal-large {
  max-width: 920px;
  border-color: var(--border-light);
  box-shadow: var(--shadow-lg);
}

.modal-top {
  margin-bottom: 16px;
  padding-bottom: 14px;
  border-bottom: 1px solid var(--border-color);
}

.modal-title { font-size: 20px; font-weight: 800; margin-bottom: 4px; }
.modal-subtitle { color: var(--text-secondary); font-size: 13px; }

.barber-warning-modal { max-width: 420px; }

.modal-section {
  border: 1px solid var(--border-color);
  background: rgba(255, 255, 255, 0.01);
  border-radius: var(--radius-md);
  padding: 14px;
  margin-bottom: 14px;
}

.section-title-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  margin-bottom: 12px;
}

.section-title {
  font-size: 14px;
  font-weight: 700;
  color: var(--text-primary);
}

.section-help {
  font-size: 12px;
  color: var(--text-tertiary);
}

.range-impact-note {
  font-size: 12px;
  color: var(--text-secondary);
  background: rgba(99, 102, 241, 0.08);
  border: 1px solid rgba(99, 102, 241, 0.24);
  border-radius: var(--radius-sm);
  padding: 8px 10px;
  margin-bottom: 10px;
}

.notes-field { margin-top: 12px; margin-bottom: 0; }

.modal-actions {
  display: flex;
  gap: 12px;
  justify-content: flex-end;
  margin-top: 20px;
  padding-top: 14px;
  border-top: 1px solid var(--border-color);
  flex-wrap: wrap;
}

.warning-box {
  margin-top: 8px;
  padding: 14px 16px;
  border-radius: var(--radius-md);
  border: 1px solid rgba(245, 158, 11, 0.35);
  background: rgba(245, 158, 11, 0.08);
  font-size: 13px;
}
.warning-box strong { display: block; margin-bottom: 6px; }
.warning-list { margin: 8px 0 0 18px; }
.warning-cta { margin-top: 10px; }

.modal-section :deep(.schedule-grid) { gap: 8px; }
.modal-section :deep(.day-row) {
  padding: 14px 16px;
  border-radius: var(--radius-md);
  background: var(--bg-secondary);
}

@media (max-width: 768px) {
  .program-item { flex-direction: column; align-items: flex-start; }
  .section-title-row { flex-direction: column; align-items: flex-start; margin-bottom: 10px; }
  .modal-section { padding: 12px; }
  .modal-actions .btn { flex: 1 1 auto; min-width: 0; }
}
</style>





