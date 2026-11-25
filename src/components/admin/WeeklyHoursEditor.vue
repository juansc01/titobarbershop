<template>
  <div class="schedule-grid">
    <div
      v-for="(day, idx) in days"
      :key="idx"
      class="day-row card"
      :class="{ 'day-row-inactive': isInactiveDay(idx) }"
    >
      <div class="day-header">
        <label class="checkbox-item">
          <input type="checkbox" v-model="localHours[idx].is_working" :disabled="isInactiveDay(idx)" />
          <span class="day-name">{{ day }}</span>
        </label>
        <span v-if="isInactiveDay(idx)" class="inactive-tag">Fuera del rango</span>
      </div>

      <div v-if="localHours[idx].is_working" class="day-content">
        <label class="checkbox-item">
          <input type="checkbox" v-model="localHours[idx].has_break" :disabled="isInactiveDay(idx)" />
          <span class="split-label">Turno partido</span>
        </label>

        <div v-if="!localHours[idx].has_break" class="day-times">
          <label class="sub-label">Horario completo</label>
          <input type="time" step="900" class="input time-input" v-model="localHours[idx].start_time" :disabled="isInactiveDay(idx)" />
          <span class="time-sep">a</span>
          <input type="time" step="900" class="input time-input" v-model="localHours[idx].end_time" :disabled="isInactiveDay(idx)" />
        </div>

        <div v-if="localHours[idx].has_break" class="split-shift">
          <div class="shift-block">
            <label class="sub-label">Turno 1</label>
            <input type="time" step="900" class="input time-input" v-model="localHours[idx].start_time" :disabled="isInactiveDay(idx)" />
            <span class="time-sep">a</span>
            <input type="time" step="900" class="input time-input" v-model="localHours[idx].break_start_time" :disabled="isInactiveDay(idx)" />
          </div>
          <div class="shift-block">
            <label class="sub-label">Descanso</label>
            <input type="time" step="900" class="input time-input" v-model="localHours[idx].break_start_time" disabled style="opacity: 0.6;" />
            <span class="time-sep">a</span>
            <input type="time" step="900" class="input time-input" v-model="localHours[idx].break_end_time" :disabled="isInactiveDay(idx)" />
          </div>
          <div class="shift-block">
            <label class="sub-label">Turno 2</label>
            <input type="time" step="900" class="input time-input" v-model="localHours[idx].break_end_time" disabled style="opacity: 0.6;" />
            <span class="time-sep">a</span>
            <input type="time" step="900" class="input time-input" v-model="localHours[idx].end_time" :disabled="isInactiveDay(idx)" />
          </div>
        </div>
      </div>

      <span v-else class="closed-label">Cerrado</span>
    </div>
  </div>
</template>

<script>
export default {
  name: 'WeeklyHoursEditor',
  props: {
    modelValue: {
      type: Array,
      required: true
    },
    days: {
      type: Array,
      default: () => ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo']
    },
    activeDayIndexes: {
      type: Array,
      default: () => []
    },
    disableInactiveDays: {
      type: Boolean,
      default: false
    }
  },
  emits: ['update:modelValue'],
  data() {
    return {
      localHours: this.cloneHours(this.modelValue)
    }
  },
  watch: {
    modelValue: {
      deep: true,
      handler(newValue) {
        this.localHours = this.cloneHours(newValue)
      }
    },
    localHours: {
      deep: true,
      handler(newValue) {
        this.$emit('update:modelValue', this.cloneHours(newValue))
      }
    }
  },
  methods: {
    isInactiveDay(dayIdx) {
      if (!this.disableInactiveDays) return false
      if (!Array.isArray(this.activeDayIndexes) || this.activeDayIndexes.length === 0) return false
      return !this.activeDayIndexes.includes(dayIdx)
    },
    cloneHours(hours) {
      return Array.from({ length: 7 }, (_, i) => ({
        day_of_week: i,
        start_time: hours?.[i]?.start_time || '09:00',
        end_time: hours?.[i]?.end_time || '15:00',
        is_working: Boolean(hours?.[i]?.is_working),
        has_break: Boolean(hours?.[i]?.has_break),
        break_start_time: hours?.[i]?.break_start_time || '12:00',
        break_end_time: hours?.[i]?.break_end_time || '13:00'
      }))
    }
  }
}
</script>

<style scoped>
.schedule-grid { display: flex; flex-direction: column; gap: 10px; }
.day-row { display: flex; flex-direction: column; gap: 12px; padding: 16px 20px; }
.day-row-inactive { opacity: 0.7; border-style: dashed; }
.day-header { display: flex; align-items: center; justify-content: space-between; gap: 8px; }
.day-content { display: flex; flex-direction: column; gap: 12px; margin-left: 26px; }
.checkbox-item { display: flex; align-items: center; gap: 10px; cursor: pointer; font-size: 14px; }
.checkbox-item input { width: 16px; height: 16px; accent-color: var(--accent); }
.day-name { font-weight: 500; min-width: 90px; }
.inactive-tag {
  font-size: 11px;
  color: var(--text-tertiary);
  border: 1px dashed var(--border-light);
  border-radius: 999px;
  padding: 2px 8px;
}
.day-times { display: flex; flex-direction: column; gap: 8px; }
.time-input { width: 110px; text-align: center; }
.time-sep { color: var(--text-tertiary); font-size: 13px; }
.closed-label { font-size: 13px; color: var(--text-tertiary); }
.split-shift { display: flex; flex-direction: column; gap: 10px; }
.shift-block { display: flex; flex-direction: column; gap: 6px; padding: 8px; background: rgba(99, 102, 241, 0.05); border-radius: 4px; }
.split-label { font-size: 13px; color: var(--text-secondary); }
.sub-label { font-size: 12px; color: var(--text-secondary); margin-bottom: 4px; display: block; }
</style>



