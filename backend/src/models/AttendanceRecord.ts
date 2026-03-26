import mongoose, { Schema, Document } from 'mongoose';

export interface IAttendanceRecord extends Document {
  employeeId: string;
  employeeName: string;
  department: string;
  timestamp: Date;
  status: 'present' | 'unrecognized';
  photoBase64: string | null;
}

const AttendanceRecordSchema = new Schema<IAttendanceRecord>(
  {
    employeeId: { type: String, required: true },
    employeeName: { type: String, required: true },
    department: { type: String, default: '' },
    timestamp: { type: Date, default: Date.now },
    status: { type: String, enum: ['present', 'unrecognized'], required: true },
    photoBase64: { type: String, default: null },
  },
  { timestamps: false }
);

export const AttendanceRecord = mongoose.model<IAttendanceRecord>(
  'AttendanceRecord',
  AttendanceRecordSchema
);
