import mongoose, { Schema, Document } from 'mongoose';

export interface ISchool extends Document {
  schoolCode: string;
  name: string;
  address: string;
  phone: string;
  email: string;
  createdAt: Date;
}

const SchoolSchema = new Schema<ISchool>(
  {
    schoolCode: { type: String, required: true, unique: true, trim: true, uppercase: true },
    name: { type: String, required: true, trim: true },
    address: { type: String, default: '' },
    phone: { type: String, default: '' },
    email: { type: String, default: '' },
  },
  { timestamps: true }
);

export const School = mongoose.model<ISchool>('School', SchoolSchema);
