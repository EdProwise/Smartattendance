import mongoose, { Schema, Document } from 'mongoose';

export interface IUser extends Document {
  loginId: string;
  email: string;
  passwordHash: string;
  role: string;       // 'admin' | 'school_admin' | 'user'
  schoolId?: string;  // set for school_admin users (School _id as string)
  createdAt: Date;
  resetToken?: string;
  resetTokenExpiry?: Date;
}

const UserSchema = new Schema<IUser>(
  {
    loginId: { type: String, required: true, unique: true, trim: true },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    passwordHash: { type: String, required: true },
    role: { type: String, default: 'user' },
    schoolId: { type: String, default: null },
    resetToken: { type: String },
    resetTokenExpiry: { type: Date },
  },
  { timestamps: true }
);

export const User = mongoose.model<IUser>('User', UserSchema);
