import mongoose, { Schema, Document } from 'mongoose';

export interface IAttendanceRecord extends Document {
  schoolId: string | null;
  employeeId: string;
  employeeName: string;
  department: string;
  timestamp: Date;
  status: 'present' | 'unrecognized';
  type: 'checkin' | 'checkout';
  photoBase64: string | null;
}

const AttendanceRecordSchema = new Schema<IAttendanceRecord>(
  {
    schoolId: { type: String, default: null, index: true },
    employeeId: { type: String, required: true },
    employeeName: { type: String, required: true },
    department: { type: String, default: '' },
    timestamp: { type: Date, default: Date.now },
    status: { type: String, enum: ['present', 'unrecognized'], required: true },
    type: { type: String, enum: ['checkin', 'checkout'], default: 'checkin' },
    photoBase64: { type: String, default: null },
  },
  { timestamps: false }
);

export const AttendanceRecord = mongoose.model<IAttendanceRecord>(
  'AttendanceRecord',
  AttendanceRecordSchema
);
